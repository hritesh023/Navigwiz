import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/research.dart';
import '../services/ai_service.dart';

class ResearchProvider extends ChangeNotifier {
  final AIService _aiService;
  List<TaskObjective> _objectives = [];
  TaskObjective? _activeObjective;
  bool _isResearching = false;
  String? _error;
  String _currentProgress = '';

  ResearchProvider({AIService? aiService}) : _aiService = aiService ?? AIService();

  List<TaskObjective> get objectives => _objectives;
  TaskObjective? get activeObjective => _activeObjective;
  bool get isResearching => _isResearching;
  String? get error => _error;
  String get currentProgress => _currentProgress;

  static const List<String> _exampleObjectives = [
    'Research the best laptops under \u20B980,000 for programming',
    'Compare Flutter vs React Native in 2026',
    'Find software engineering internships in India',
    'Analyze competitors for my startup',
    'Summarize recent AI developments',
    'Create a travel itinerary for Bangalore to Goa',
  ];

  List<String> get exampleObjectives => _exampleObjectives;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('research_objectives');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      _objectives = list.map((o) => TaskObjective.fromJson(o)).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_objectives.map((o) => o.toJson()).toList());
    await prefs.setString('research_objectives', data);
  }

  void setActiveObjective(String id) {
    _activeObjective = _objectives.firstWhere((o) => o.id == id);
    notifyListeners();
  }

  void clearActiveObjective() {
    _activeObjective = null;
    notifyListeners();
  }

  Future<void> startResearch(String objective, {String category = 'general'}) async {
    final task = TaskObjective(
      id: 'research_${DateTime.now().millisecondsSinceEpoch}',
      objective: objective,
      category: category,
    );
    _objectives.insert(0, task);
    _activeObjective = task;
    _isResearching = true;
    _error = null;
    _currentProgress = 'Starting research...';
    notifyListeners();

    try {
      _currentProgress = 'Planning research strategy...';
      notifyListeners();

      final agentResult = await _aiService.runResearchAgent(objective);
      final research = agentResult.research;

      if (research != null || agentResult.response.isNotEmpty) {
        final references = (research?.references ?? const [])
            .map((r) => ResearchSource(
                  title: r.title,
                  url: r.url,
                  snippet: r.snippet,
                ))
            .toList();

        final findings = research == null
            ? <ResearchFinding>[]
            : research.keyFindings.asMap().entries.map((e) {
                final finding = e.value;
                final src = finding.sources.isNotEmpty
                    ? finding.sources.first
                    : (e.key < references.length
                        ? references[e.key].url
                        : (references.isNotEmpty ? references.first.url : ''));
                return ResearchFinding(
                  id: 'finding_${e.key}',
                  title: finding.title,
                  finding: finding.finding.isNotEmpty
                      ? finding.finding
                      : finding.title,
                  source: src,
                  sources: finding.sources,
                );
              }).toList();

        final report = ResearchReport(
          id: 'report_${DateTime.now().millisecondsSinceEpoch}',
          query: objective,
          executiveSummary: research?.executiveSummary.isNotEmpty == true
              ? research!.executiveSummary
              : agentResult.response,
          keyFindings: findings,
          recommendations: research?.recommendations ?? const [],
          references: references,
        );

        final index = _objectives.indexWhere((o) => o.id == task.id);
        if (index != -1) {
          _objectives[index] = TaskObjective(
            id: task.id,
            objective: objective,
            category: category,
            status: 'completed',
            report: report,
            createdAt: task.createdAt,
          );
          _activeObjective = _objectives[index];
        }
        _isResearching = false;
        _currentProgress = 'Research complete';
        await _save();
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Worker research failed, using fallback: $e');
    }

    try {
      _currentProgress = 'Searching multiple sources...';
      notifyListeners();

      final searchResults = await _aiService.searchWeb(objective);

      _currentProgress = 'Analyzing ${searchResults.length} sources...';
      notifyListeners();

      _currentProgress = 'Extracting key findings and generating insights...';
      notifyListeners();

      final report = await _generateReport(objective, searchResults);

      final index = _objectives.indexWhere((o) => o.id == task.id);
      if (index != -1) {
        _objectives[index] = TaskObjective(
          id: task.id,
          objective: objective,
          category: category,
          status: 'completed',
          report: report,
          createdAt: task.createdAt,
        );
        _activeObjective = _objectives[index];
      }

      _isResearching = false;
      _currentProgress = 'Research complete';
      await _save();
      notifyListeners();
    } catch (e) {
      _isResearching = false;
      _error = e.toString();
      _currentProgress = 'Research failed';
      notifyListeners();
    }
  }

  Future<ResearchReport> _generateReport(String objective, List<SearchResult> searchResults) async {
    final sources = searchResults.map((r) => ResearchSource(
      title: r.title,
      url: r.url,
      snippet: r.description,
      relevanceScore: r.relevanceScore,
    )).toList();

    final topSources = sources.take(8).toList();
    final sourceText = topSources.asMap().entries.map((e) =>
      'Source ${e.key + 1}: ${e.value.title}\n  URL: ${e.value.url}\n  Content: ${e.value.snippet}'
    ).join('\n\n');

    String aiReport = '';
    try {
      aiReport = await _aiService.askAi(
        'Research Objective: $objective\n\n'
        'Search Results:\n$sourceText\n\n'
        'Generate a comprehensive research report with:\n'
        '1. Executive Summary (2-3 paragraphs)\n'
        '2. Key Findings (5-8 bullet points, each with a finding and source citation)\n'
        '3. Source Comparisons (compare different viewpoints across sources)\n'
        '4. Recommendations (3-5 actionable recommendations)\n'
        '5. References (list all sources with URLs)\n\n'
        'Format the response clearly with section headers.',
        extraInstructions: 'You are a professional research analyst. Provide well-structured, '
            'insightful analysis. Be specific and cite sources. Use markdown formatting.',
      );
    } catch (_) {}

    if (aiReport.isNotEmpty) {
      final executiveSummary = _extractSection(aiReport, 'Executive Summary', 'Key Findings');
      final keyFindingsText = _extractSection(aiReport, 'Key Findings', 'Source Comparison');
      final comparisonsText = _extractSection(aiReport, 'Source Comparison', 'Recommendations');
      final recommendationsText = _extractSection(aiReport, 'Recommendations', 'References');

      List<ResearchFinding> findings = [];
      if (keyFindingsText.isNotEmpty) {
        final lines = keyFindingsText.split('\n').where((l) {
          final t = l.trim();
          return t.startsWith('-') || t.startsWith('*') || RegExp(r'^\d+\.').hasMatch(t);
        }).toList();
        findings = lines.take(8).toList().asMap().entries.map((e) {
          final findingText = e.value.replaceAll(RegExp(r'^[\s*\-0-9.]+'), '').trim();
          return ResearchFinding(
            id: 'finding_${e.key}',
            finding: findingText.length > 300 ? '${findingText.substring(0, 300)}...' : findingText,
            source: topSources[e.key % topSources.length].url,
          );
        }).toList();
      }

      List<ResearchComparison> comparisons = [];
      if (comparisonsText.isNotEmpty) {
        final compLines = comparisonsText.split('\n').where((l) => l.trim().contains(':')).take(4).toList();
        comparisons = compLines.asMap().entries.map((e) {
          final parts = e.value.split(':');
          return ResearchComparison(
            aspect: parts[0].trim().replaceAll(RegExp(r'^[\s*\-]+'), ''),
            values: {'perspective': parts.length > 1 ? parts.sublist(1).join(':').trim() : ''},
          );
        }).toList();
      }

      List<String> recommendations = [];
      if (recommendationsText.isNotEmpty) {
        recommendations = recommendationsText.split('\n')
            .where((l) { final t = l.trim(); return t.startsWith('-') || t.startsWith('*') || RegExp(r'^\d+\.').hasMatch(t); })
            .map((l) => l.replaceAll(RegExp(r'^[\s*\-0-9.]+'), '').trim())
            .where((l) => l.isNotEmpty)
            .take(5)
            .toList();
      }

      return ResearchReport(
        id: 'report_${DateTime.now().millisecondsSinceEpoch}',
        query: objective,
        executiveSummary: executiveSummary.isNotEmpty
            ? executiveSummary
            : 'Research completed for: $objective. Analyzed ${sources.length} sources across multiple platforms.',
        keyFindings: findings.isNotEmpty ? findings : topSources.take(5).toList().asMap().entries.map((e) => ResearchFinding(
          id: 'finding_${e.key}',
          finding: e.value.snippet.length > 200 ? '${e.value.snippet.substring(0, 200)}...' : e.value.snippet,
          source: e.value.url,
        )).toList(),
        comparisons: comparisons,
        recommendations: recommendations.isNotEmpty
            ? recommendations
            : ['Review top ${sources.length} sources for detailed information'],
        references: sources,
      );
    }

    final findings = topSources.take(5).toList().asMap().entries.map((e) => ResearchFinding(
      id: 'finding_${e.key}',
      finding: e.value.snippet.length > 200 ? '${e.value.snippet.substring(0, 200)}...' : e.value.snippet,
      source: e.value.url,
    )).toList();

    return ResearchReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      query: objective,
      executiveSummary: 'Research completed for: $objective. Analyzed ${sources.length} sources across multiple platforms. '
          'The findings below represent the most relevant information gathered from web search results.',
      keyFindings: findings,
      comparisons: [],
      recommendations: ['Review the top ${sources.length} sources for detailed insights on $objective'],
      references: sources,
    );
  }

  String _extractSection(String text, String sectionName, String nextSection) {
    final escapedSection = RegExp.escape(sectionName);
    final escapedNext = RegExp.escape(nextSection);
    final regex = RegExp('$escapedSection[\\s\\S]*?(?=$escapedNext|\$)');
    final match = regex.firstMatch(text);
    if (match != null) {
      return match.group(0)!.replaceAll(RegExp('^$escapedSection[\\s:]*'), '').trim();
    }
    return '';
  }

  void cancelResearch() {
    _isResearching = false;
    _currentProgress = 'Cancelled';
    notifyListeners();
  }

  Future<void> deleteObjective(String id) async {
    _objectives.removeWhere((o) => o.id == id);
    if (_activeObjective?.id == id) _activeObjective = null;
    await _save();
    notifyListeners();
  }
}