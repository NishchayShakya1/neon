part of '../neon_notes.dart';

class NotesFloatingActionButton extends StatelessWidget {
  const NotesFloatingActionButton({
    required this.bloc,
    this.category,
    super.key,
  });

  final NotesBloc bloc;
  final String? category;

  @override
  Widget build(final BuildContext context) => FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<(String, String?)>(
            context: context,
            builder: (final context) => NotesCreateNoteDialog(
              bloc: bloc,
              category: category,
            ),
          );
          if (result != null) {
            final (title, category) = result;
            bloc.createNote(
              title: title,
              category: category ?? '',
            );
          }
        },
        tooltip: NotesLocalizations.of(context).noteCreate,
        child: const Icon(Icons.add),
      );
}
