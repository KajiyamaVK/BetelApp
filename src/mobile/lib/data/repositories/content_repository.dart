import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:betelsas/data/models/lesson.dart';

class ContentRepository {
  Future<List<Lesson>> loadLessons() async {
    try {
      final String response = await rootBundle.loadString('assets/data/lessons.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      // In a real app, log this error
      print('Error loading lessons: $e');
      return [];
    }
  }
}
