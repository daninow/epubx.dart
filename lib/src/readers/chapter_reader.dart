import 'package:collection/collection.dart';

import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_chapter_ref.dart';
import '../ref_entities/epub_text_content_file_ref.dart';
import '../schema/navigation/epub_navigation_point.dart';

class ChapterReader {
  static List<EpubChapterRef> getChapters(EpubBookRef bookRef) {
    if (bookRef.Schema!.Navigation == null) {
      return <EpubChapterRef>[];
    }
    return getChaptersImpl(
        bookRef, bookRef.Schema!.Navigation!.NavMap!.Points!);
  }

  static String _cleanPath(String contentFileName) {
    contentFileName = Uri.decodeFull(contentFileName);
    var segments = contentFileName.split('/');
    if (segments.first == '..') {
      segments.removeAt(0);
      contentFileName = segments.join('/');
    }
    return contentFileName;
  }

  static List<EpubChapterRef> getChaptersImpl(
      EpubBookRef bookRef, List<EpubNavigationPoint> navigationPoints) {
    var result = <EpubChapterRef>[];
    var spine = bookRef.Schema!.Package!.Spine!.Items!;
    var manifest = bookRef.Schema!.Package!.Manifest!.Items!;
    for (final column in spine) {
      var contentFileName =
          manifest.firstWhere((e) => e.Id == column.IdRef).Href!;
      String? anchor;
      var contentSourceAnchorCharIndex = contentFileName.indexOf('#');
      if (contentSourceAnchorCharIndex == -1) {
        anchor = null;
      } else {
        contentFileName =
            contentFileName.substring(0, contentSourceAnchorCharIndex);
        anchor = contentFileName.substring(contentSourceAnchorCharIndex + 1);
      }
      contentFileName = _cleanPath(contentFileName);
      EpubTextContentFileRef? htmlContentFileRef;
      if (!bookRef.Content!.Html!.containsKey(contentFileName)) {
        throw Exception(
            'Incorrect EPUB manifest: item with href = \"$contentFileName\" is missing.');
      }

      htmlContentFileRef = bookRef.Content!.Html![contentFileName];
      var chapterRef = EpubChapterRef(htmlContentFileRef);
      chapterRef.ContentFileName = contentFileName;
      chapterRef.Anchor = anchor;
      final navPts = bookRef.Schema!.Navigation!.NavMap!.Points!;
      final navPt = navPts.firstWhereOrNull((e) =>
          (_cleanPath(e.Content!.Source!) == contentFileName) ||
          (e.Content!.Id == column.IdRef));

      chapterRef.Title = navPt?.NavigationLabels!.first.Text;
      chapterRef.SubChapters = navPt?.ChildNavigationPoints?.isNotEmpty == true
          ? getChaptersImpl(bookRef, navPt?.ChildNavigationPoints ?? [])
          : [];

      result.add(chapterRef);
    }
    return result;
  }
}
