import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/research_provider.dart';
import '../services/browser_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key});

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startResearch(String objective) async {
    final provider = Provider.of<ResearchProvider>(context, listen: false);
    await provider.startResearch(objective);
  }

  void _openUrl(String url) {
    if (Provider.of<BrowserService>(context, listen: false).webViewController !=
        null) {
      Provider.of<BrowserService>(context, listen: false).navigateToUrl(url);
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Research Mode'),
        centerTitle: true,
      ),
      body: Consumer<ResearchProvider>(
        builder: (context, rp, _) {
          if (rp.isResearching) return _buildResearching(rp, theme);
          if (rp.activeObjective != null) {
            return _buildReport(rp, theme);
          }
          return _buildObjectiveList(rp, theme);
        },
      ),
    );
  }

  Widget _buildObjectiveList(ResearchProvider rp, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.2),
                primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.travel_explore,
                        size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text('Deep Research',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'The Navigwiz agentic AI plans, searches multiple sources, and '
                'synthesizes a structured report with findings, recommendations and links.',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.travel_explore, color: primary),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _startResearch(v.trim());
                  },
                  style: TextStyle(
                      fontSize: 15, color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'What should I research?',
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(6),
                child: FilledButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      _startResearch(_controller.text.trim());
                    }
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Icon(Icons.arrow_forward, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Try one of these',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rp.exampleObjectives
              .map((o) => ActionChip(
                    avatar: Icon(Icons.auto_awesome,
                        size: 14, color: primary),
                    label: Text(o,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface)),
                    onPressed: () => _startResearch(o),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: primary.withValues(alpha: 0.3)),
                  ))
              .toList(),
        ),
        if (rp.objectives.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Previous research',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text('${rp.objectives.length}',
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ...rp.objectives.map((o) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: o.status == 'completed'
                          ? primary.withValues(alpha: 0.14)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                        o.status == 'completed'
                            ? Icons.task_alt
                            : Icons.schedule,
                        color: o.status == 'completed'
                            ? primary
                            : Colors.grey,
                        size: 20),
                  ),
                  title: Text(o.objective,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                        o.report != null
                            ? '${o.report!.keyFindings.length} findings • ${o.report!.references.length} sources'
                            : o.status,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  trailing: PopupMenuButton(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    itemBuilder: (ctx) => [
                      if (o.status == 'completed')
                        PopupMenuItem(
                          child: const Row(children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('View Report')
                          ]),
                          onTap: () => rp.setActiveObjective(o.id),
                        ),
                      PopupMenuItem(
                        child: const Row(children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: Colors.red))
                        ]),
                        onTap: () => rp.deleteObjective(o.id),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (o.status == 'completed') rp.setActiveObjective(o.id);
                  },
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildResearching(ResearchProvider rp, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    const steps = [
      'Planning research strategy',
      'Searching multiple sources',
      'Analyzing results',
      'Extracting key findings',
      'Writing the report',
    ];
    final activeStep = rp.currentProgress.toLowerCase().contains('planning')
        ? 0
        : rp.currentProgress.toLowerCase().contains('search')
            ? 1
            : rp.currentProgress.toLowerCase().contains('analyz')
                ? 2
                : rp.currentProgress.toLowerCase().contains('finding')
                    ? 3
                    : 4;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_alt,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text('Researching…',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 6),
            Text(rp.currentProgress,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            ...steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.key <= activeStep
                              ? primary
                              : theme.colorScheme.surfaceContainerHighest,
                          border: e.key > activeStep
                              ? Border.all(color: theme.dividerColor)
                              : null,
                        ),
                        child: e.key < activeStep
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : e.key == activeStep
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : null,
                      ),
                      const SizedBox(width: 10),
                      Text(steps[e.key],
                          style: TextStyle(
                              fontSize: 13,
                              color: e.key <= activeStep
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                rp.cancelResearch();
                if (rp.activeObjective != null &&
                    rp.activeObjective!.report == null) {
                  rp.deleteObjective(rp.activeObjective!.id);
                }
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(ResearchProvider rp, ThemeData theme) {
    final report = rp.activeObjective!.report;
    if (report == null) return const SizedBox.shrink();
    final primary = theme.colorScheme.primary;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => rp.clearActiveObjective(),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('All research', style: TextStyle(fontSize: 13)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open first source',
                icon: Icon(Icons.open_in_new,
                    size: 18, color: theme.colorScheme.primary),
                onPressed: () {
                  if (report.references.isNotEmpty) {
                    _openUrl(report.references.first.url);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.16),
                      primary.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: primary),
                        const SizedBox(width: 6),
                        Text('RESEARCH REPORT',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: primary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(report.query,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                        '${report.keyFindings.length} findings • ${report.references.length} sources',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(theme, Icons.summarize_outlined, 'Executive Summary',
                  report.executiveSummary),
              if (report.keyFindings.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Key Findings',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 10),
                ...report.keyFindings.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (f.title.isNotEmpty) ...[
                            Text(f.title,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 4),
                          ],
                          Text(f.finding,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: theme.colorScheme.onSurfaceVariant)),
                          if (f.source.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _openUrl(f.source),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link,
                                      size: 12, color: primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(_hostOf(f.source),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: primary,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],
              if (report.recommendations.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Recommendations',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 10),
                ...report.recommendations
                    .asMap()
                    .entries
                    .map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primary.withValues(alpha: 0.12),
                                primary.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(e.value,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color:
                                            theme.colorScheme.onSurface)),
                              ),
                            ],
                          ),
                        )),
              ],
              if (report.references.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('References',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 10),
                ...report.references.map((ref) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.4)),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        dense: true,
                        leading: Icon(Icons.link,
                            size: 16, color: primary),
                        title: Text(ref.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface)),
                        subtitle: ref.snippet.isNotEmpty
                            ? Text(ref.snippet,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme
                                        .colorScheme.onSurfaceVariant))
                            : Text(_hostOf(ref.url),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: primary)),
                        trailing: Icon(Icons.north_east,
                            size: 14, color: primary.withValues(alpha: 0.7)),
                        onTap: () => _openUrl(ref.url),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
      ThemeData theme, IconData icon, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _hostOf(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}
