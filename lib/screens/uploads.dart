import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../components/components.dart';
import '../core/session.dart';

class UploadsScreen extends StatelessWidget {
  const UploadsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final queue = AppScope.of(context).uploads;
    return AppScaffold(
      appBar: AppHeader(title: Text(context.l10n.uploads)),
      body: ListenableBuilder(
        listenable: queue,
        builder: (context, _) => queue.jobs.isEmpty
            ? const ScreenStatus()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: queue.jobs.length,
                itemBuilder: (context, i) {
                  final job = queue.jobs[i];
                  return AppSection(
                    children: [
                      AppRow(
                        leading: Icon(
                          job.status == 'done'
                              ? Icons.check_circle_outline
                              : job.status == 'failed'
                              ? Icons.error_outline
                              : Icons.cloud_upload_outlined,
                        ),
                        title: Text(job.title),
                        subtitle: Text(
                          job.error ??
                              ({
                                    'done': context.l10n.uploadStatusUploaded,
                                    'queued': context.l10n.uploadStatusQueued,
                                    'sending':
                                        context.l10n.uploadStatusUploading,
                                    'failed': context.l10n.uploadStatusFailed,
                                  }[job.status] ??
                                  job.status),
                        ),
                        trailing: job.status == 'failed'
                            ? AppIconButton(
                                tooltip: context.l10n.retry,
                                icon: const Icon(Icons.refresh),
                                onPressed: () =>
                                    perform(context, () => queue.retry(job)),
                              )
                            : AppIconButton(
                                tooltip: context.l10n.remove,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    perform(context, () => queue.remove(job)),
                              ),
                      ),
                      if (job.status == 'sending')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: LinearProgressIndicator(
                            value: job.progress > 0 ? job.progress : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
