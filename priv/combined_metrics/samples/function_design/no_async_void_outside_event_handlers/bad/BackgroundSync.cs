using System;
using System.Threading.Tasks;

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

        // async void: callers cannot await this; exceptions crash the process unhandled
        public async void Synchronize()
        {
            var pending = await _repository.GetPendingItemsAsync();
            foreach (var item in pending)
            {
                await _repository.PushItemAsync(item);
                await _repository.MarkSyncedAsync(item.Id);
            }
        }

        // async void: caller cannot observe exceptions or know when it finishes
        public async void SynchronizeWithLogging()
        {
            try
            {
                var pending = await _repository.GetPendingItemsAsync();
                foreach (var item in pending)
                {
                    await _repository.PushItemAsync(item);
                    await _repository.MarkSyncedAsync(item.Id);
                }
            }
            catch (Exception ex)
            {
                // Exception is swallowed here; no way for callers to know about it
                _logger.Error("Sync failed", ex);
            }
        }

        // async void: cannot be unit tested properly; cannot be awaited in service startup
        public async void RetryFailed()
        {
            var failed = await _repository.GetFailedItemsAsync();
            foreach (var item in failed)
                await _repository.PushItemAsync(item);
        }

        public void TriggerSync()
        {
            // Fire-and-forget via async void — exceptions are silently lost
            Synchronize();
        }
    }
}
