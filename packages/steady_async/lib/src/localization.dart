import 'package:flutter/widgets.dart';

/// User-facing strings used by the default widgets.
@immutable
class SteadyMessages {
  const SteadyMessages({
    required this.loading,
    required this.empty,
    required this.error,
    required this.retry,
    required this.success,
  });

  final String loading;
  final String empty;
  final String error;
  final String retry;
  final String success;

  static const english = SteadyMessages(
    loading: 'Loading…',
    empty: 'Nothing here yet',
    error: 'Something went wrong',
    retry: 'Try again',
    success: 'Done',
  );

  static const Map<String, SteadyMessages> supported = {
    'en': english,
    'hi': SteadyMessages(
      loading: 'लोड हो रहा है…',
      empty: 'अभी यहाँ कुछ नहीं है',
      error: 'कुछ गलत हो गया',
      retry: 'फिर कोशिश करें',
      success: 'हो गया',
    ),
    'ar': SteadyMessages(
      loading: 'جارٍ التحميل…',
      empty: 'لا يوجد شيء هنا بعد',
      error: 'حدث خطأ ما',
      retry: 'حاول مرة أخرى',
      success: 'تم',
    ),
    'es': SteadyMessages(
      loading: 'Cargando…',
      empty: 'Todavía no hay nada aquí',
      error: 'Algo salió mal',
      retry: 'Reintentar',
      success: 'Listo',
    ),
    'fr': SteadyMessages(
      loading: 'Chargement…',
      empty: 'Rien ici pour le moment',
      error: 'Un problème est survenu',
      retry: 'Réessayer',
      success: 'Terminé',
    ),
    'de': SteadyMessages(
      loading: 'Wird geladen…',
      empty: 'Noch nichts vorhanden',
      error: 'Etwas ist schiefgelaufen',
      retry: 'Erneut versuchen',
      success: 'Fertig',
    ),
    'pt': SteadyMessages(
      loading: 'Carregando…',
      empty: 'Ainda não há nada aqui',
      error: 'Algo deu errado',
      retry: 'Tentar novamente',
      success: 'Concluído',
    ),
    'zh': SteadyMessages(
      loading: '加载中…',
      empty: '这里还没有内容',
      error: '出现了问题',
      retry: '重试',
      success: '完成',
    ),
    'ja': SteadyMessages(
      loading: '読み込み中…',
      empty: 'まだ何もありません',
      error: '問題が発生しました',
      retry: '再試行',
      success: '完了',
    ),
  };

  static SteadyMessages resolve(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return supported[locale?.languageCode] ?? english;
  }
}
