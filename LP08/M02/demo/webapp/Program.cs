using Azure.Identity;
using Microsoft.FeatureManagement;

// LP08 / M02 - App Configuration dynamic refresh with a sentinel key
// (adapted from the AZ-204 Mod07AppConfig demo).
//
// Only the sentinel key (TestingApp:DefaultSettings:HasChanged) is watched.
// Edit Color/Font/Message in the portal and the running app does NOT pick
// them up - restart it and it does. Edit them, then change the sentinel's
// value, and refreshAll reloads every TestingApp:* key with no restart.

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

// Same variable the Python demos use. Authenticates with Entra ID
// (DefaultAzureCredential = your az login locally, managed identity in
// Azure) - 01-create-app-configuration grants you App Configuration Data
// Owner, so no connection string or access key is involved.
var endpoint = builder.Configuration["APPCONFIG_ENDPOINT"]
    ?? throw new InvalidOperationException(
        "Set APPCONFIG_ENDPOINT (e.g. export APPCONFIG_ENDPOINT=https://appcs-<suffix>.azconfig.io)");

// Locally, skip the managed identity probe: on networks that drop traffic
// to the Azure metadata endpoint (169.254.169.254) instead of refusing it,
// it hangs until the provider's 100s startup timeout ("The provider timed
// out while attempting to load"), long before the az login credential gets
// a turn. In Azure, managed identity stays first in the chain.
var credential = builder.Environment.IsDevelopment()
    ? new DefaultAzureCredential(new DefaultAzureCredentialOptions { ExcludeManagedIdentityCredential = true })
    : new DefaultAzureCredential();

builder.Configuration.AddAzureAppConfiguration(opt =>
{
    opt.Connect(new Uri(endpoint), credential)
        // Only this app's keys (no label) - the store also holds the
        // Python demos' labeled Pipeline:* keys and a Key Vault reference
        // this app doesn't need (and would need Key Vault access to load).
        .Select("TestingApp:*")
        .ConfigureRefresh(refresh => refresh
            // The sentinel: the ONLY key polled for changes. When its value
            // changes, refreshAll reloads every selected key, so a batch of
            // edits lands together instead of one key at a time.
            .Register("TestingApp:DefaultSettings:HasChanged", refreshAll: true)
            // Default is 30s; shorter so the demo doesn't drag.
            .SetRefreshInterval(TimeSpan.FromSeconds(10)))
        // Feature flags are refreshed on their own interval, independent of
        // the sentinel - toggling 'xmas' never needs a sentinel change.
        .UseFeatureFlags(ff => ff.SetRefreshInterval(TimeSpan.FromSeconds(10)));
});

builder.Services.AddAzureAppConfiguration();
builder.Services.AddFeatureManagement();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// Checks the sentinel (at most once per refresh interval) as requests come
// in. The check runs in the background, so the request that triggers it
// still renders the old values - reload once more to see the new ones.
app.UseAzureAppConfiguration();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

AppInfo.StartedAt = DateTime.Now;
app.Run();

public static class AppInfo
{
    // Shown on the page so it's obvious when the app has been restarted.
    public static DateTime StartedAt { get; set; }
}
