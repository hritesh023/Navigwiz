import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/extraction.dart';

class ExtractionProvider extends ChangeNotifier {
  List<ExtractionTemplate> _templates = [];
  List<ExtractedRecord> _records = [];
  List<ExtractionTemplate> get templates => _templates;
  List<ExtractedRecord> get records => _records;
  static final List<ExtractionTemplate> _defaultTemplates = [
    ExtractionTemplate(id: 'products', name: 'Products', description: 'Product prices, names, ratings',
      fields: ['name', 'price', 'rating', 'description', 'availability'], category: 'shopping'),
    ExtractionTemplate(id: 'jobs', name: 'Job Listings', description: 'Job titles, companies, locations',
      fields: ['title', 'company', 'location', 'salary', 'type'], category: 'career'),
    ExtractionTemplate(id: 'contacts', name: 'Contact Info', description: 'Names, emails, phones',
      fields: ['name', 'email', 'phone', 'company', 'position'], category: 'business'),
    ExtractionTemplate(id: 'companies', name: 'Company Details', description: 'Company name, industry, size',
      fields: ['name', 'industry', 'employees', 'revenue', 'location'], category: 'business'),
    ExtractionTemplate(id: 'research', name: 'Research Data', description: 'Paper titles, authors, findings',
      fields: ['title', 'authors', 'year', 'findings', 'methodology'], category: 'academic'),
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTemplates = prefs.getString('extraction_templates');
    if (savedTemplates != null) {
      final list = jsonDecode(savedTemplates) as List;
      _templates = list.map((t) => ExtractionTemplate.fromJson(t)).toList();
    } else {
      _templates = List.from(_defaultTemplates);
      await _saveTemplates();
    }

    final savedRecords = prefs.getString('extraction_records');
    if (savedRecords != null) {
      final list = jsonDecode(savedRecords) as List;
      _records = list.map((r) => ExtractedRecord.fromJson(r)).toList();
    }
    notifyListeners();
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_templates.map((t) => t.toJson()).toList());
    await prefs.setString('extraction_templates', data);
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_records.map((r) => r.toJson()).toList());
    await prefs.setString('extraction_records', data);
  }

  Future<void> addRecord(ExtractedRecord record) async {
    _records.insert(0, record);
    await _saveRecords();
    notifyListeners();
  }

  void addTemplate(ExtractionTemplate template) {
    _templates.add(template);
    _saveTemplates();
    notifyListeners();
  }

  void deleteTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    _saveTemplates();
    notifyListeners();
  }

  String exportAsCsv(List<ExtractedRecord> records) {
    if (records.isEmpty) return '';
    final headers = records.first.fields.keys.join(',');
    final rows = records.map((r) => r.fields.values
      .map((v) => '"${v.replaceAll('"', '""')}"')
      .join(',')
    ).join('\n');
    return '$headers\n$rows';
  }

  String exportAsJson(List<ExtractedRecord> records) {
    return const JsonEncoder.withIndent('  ').convert(records.map((r) => r.fields).toList());
  }

  List<ExtractedRecord> searchRecords(String query) {
    final q = query.toLowerCase();
    return _records.where((r) =>
      r.fields.values.any((v) => v.toLowerCase().contains(q))
    ).toList();
  }

  void clearRecords() {
    _records.clear();
    _saveRecords();
    notifyListeners();
  }
}
