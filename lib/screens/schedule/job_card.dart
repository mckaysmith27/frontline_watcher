import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final bool isPast;

  const JobCard({
    super.key,
    required this.job,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    final jobService = JobService();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isPast ? Colors.grey[200] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Confirmation #${job.confirmationNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!isPast)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          Share.share(
                            'Job: ${job.title}\n'
                            'Date: ${job.date.toString().split(' ')[0]}\n'
                            'Time: ${job.startTime} - ${job.endTime}\n'
                            'Location: ${job.location}',
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        color: Colors.red,
                        onPressed: () async {
                          final confirmed = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cancel Job',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('${job.title} • ${job.location}'),
                                  const SizedBox(height: 8),
                                  const Text('Are you sure you want to cancel this job?'),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Keep Job'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => Navigator.pop(context, true),
                                          icon: const Icon(Icons.cancel),
                                          label: const Text('Cancel Job'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await jobService.cancelJob(job.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Job cancelled')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(),
            _buildInfoRow(Icons.person, job.teacher),
            _buildInfoRow(Icons.calendar_today, job.date.toString().split(' ')[0]),
            _buildInfoRow(Icons.access_time, '${job.startTime} - ${job.endTime}'),
            _buildInfoRow(Icons.schedule, job.duration),
            _buildInfoRow(Icons.location_on, job.location),
            if (isPast) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showReviewDialog(context, job);
                      },
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Review'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await jobService.submitTime(job.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Time submitted')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Submit Time'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, Job job) {
    final reviewController = TextEditingController();
    int stars = 0;

    showDialog(
      context: context,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          reviewController.dispose();
          return true;
        },
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Review Job'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rate this job:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() {
                            stars = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 5,
                    maxLength: 25000,
                    decoration: const InputDecoration(
                      labelText: 'Write your review',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  reviewController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (stars > 0) {
                    final jobService = JobService();
                    try {
                      await jobService.submitReview(
                        job.id,
                        reviewController.text,
                        stars,
                      );
                      reviewController.dispose();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review submitted')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


