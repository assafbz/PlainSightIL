/// Model representing a single citation source linked to a specific record in a dataset.
class CitationModel {
  final String id;
  final String datasetId;
  final String docId;
  final String title;

  CitationModel({
    required this.id,
    required this.datasetId,
    required this.docId,
    required this.title,
  });

  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      id: json['id'] as String? ?? '',
      datasetId: json['datasetId'] as String? ?? '',
      docId: json['docId'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'datasetId': datasetId, 'docId': docId, 'title': title};
  }
}

/// Model representing the full AI semantic search result containing the synthesized answer and citation list.
class AiSearchResultModel {
  final String answer;
  final List<CitationModel> citations;

  AiSearchResultModel({required this.answer, required this.citations});

  factory AiSearchResultModel.fromJson(Map<String, dynamic> json) {
    final citationsList = json['citations'] as List<dynamic>? ?? [];
    return AiSearchResultModel(
      answer: json['answer'] as String? ?? '',
      citations: citationsList
          .map((e) => CitationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'citations': citations.map((e) => e.toJson()).toList(),
    };
  }
}
