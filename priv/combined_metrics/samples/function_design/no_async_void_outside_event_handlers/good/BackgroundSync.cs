using System;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Sync
{
    public class BackgroundSync
    {
        private readonly ISyncRepository _repository;
        private readonly ILogger _logger;

        public BackgroundSync(ISyncRepository repository, ILogger logger)
        {
            _repository = repository;
            _logger = logger;
        }

        // Returns Task so callers can await, observe exceptions, and compose
        public async Task SynchronizeAsync()
        {
            var pending = await _repository.GetPendingItemsAsync();
            foreach (var item in pending)
            {
                await _repository.PushItemAsync(item);
                await _repository.MarkSyncedAsync(item.Id);
            }
        }

        public async Task<SyncResult> SynchronizeWithResultAsync()
        {
            int synced = 0;
            int failed = 0;

            var pending = await _repository.GetPendingItemsAsync();
            foreach (var item in pending)
            {
                try
                {
                    await _repository.PushItemAsync(item);
                    await _repository.MarkSyncedAsync(item.Id);
                    synced++;
                }
                catch (SyncException ex)
                {
                    _logger.Warning("Failed to sync item {id}", ex);
                    failed++;
                }
            }

            return new SyncResult(synced, failed);
        }

        // async void is acceptable ONLY for event handlers — exceptions cannot be caught otherwise
        private async void OnSyncButtonClicked(object sender, EventArgs e)
        {
            try
            {
                await SynchronizeAsync();
            }
            catch (Exception ex)
            {
                _logger.Error("Sync failed from UI button", ex);
                MessageBox.Show("Sync failed. Please try again.");
            }
        }

        public async Task RetryFailedAsync()
        {
            var failed = await _repository.GetFailedItemsAsync();
            foreach (var item in failed)
                await _repository.PushItemAsync(item);
        }
    }
}
