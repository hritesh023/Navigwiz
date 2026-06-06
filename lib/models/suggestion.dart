class Suggestion {
  final String icon;
  final String title;
  final String desc;
  final String query;
  Suggestion({required this.icon, required this.title, required this.desc, required this.query});

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    icon: json['icon'] as String? ?? '', title: json['title'] as String? ?? '',
    desc: json['desc'] as String? ?? '', query: json['query'] as String? ?? '');

  Map<String, dynamic> toJson() => {
    'icon': icon,
    'title': title,
    'desc': desc,
    'query': query,
  };

  Suggestion copyWith({String? icon, String? title, String? desc, String? query}) => Suggestion(
    icon: icon ?? this.icon,
    title: title ?? this.title,
    desc: desc ?? this.desc,
    query: query ?? this.query,
  );
}
