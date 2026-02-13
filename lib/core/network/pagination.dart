import 'dart:convert';

class PaginationMeta {
  const PaginationMeta({
    required this.totalCount,
    required this.pageSize,
    required this.currentPage,
    required this.totalPages,
  });

  final int totalCount;
  final int pageSize;
  final int currentPage;
  final int totalPages;

  factory PaginationMeta.fromHeader(String headerValue) {
    final json = jsonDecode(headerValue) as Map<String, dynamic>;
    return PaginationMeta(
      totalCount: json['totalCount'] as int,
      pageSize: json['pageSize'] as int,
      currentPage: json['currentPage'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}

class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.meta,
  });

  final List<T> items;
  final PaginationMeta meta;
}
