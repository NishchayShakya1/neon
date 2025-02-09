part of '../neon_files.dart';

class FilesChooseFolderDialog extends StatelessWidget {
  const FilesChooseFolderDialog({
    required this.bloc,
    required this.filesBloc,
    required this.originalPath,
    super.key,
  });

  final FilesBrowserBloc bloc;
  final FilesBloc filesBloc;

  final List<String> originalPath;

  @override
  Widget build(final BuildContext context) => AlertDialog(
        title: Text(FilesLocalizations.of(context).folderChoose),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            children: [
              Expanded(
                child: FilesBrowserView(
                  bloc: bloc,
                  filesBloc: filesBloc,
                  mode: FilesBrowserMode.selectDirectory,
                ),
              ),
              StreamBuilder<List<String>>(
                stream: bloc.path,
                builder: (final context, final pathSnapshot) => pathSnapshot.hasData
                    ? Container(
                        margin: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final result = await showDialog<List<String>>(
                                  context: context,
                                  builder: (final context) => const FilesCreateFolderDialog(),
                                );
                                if (result != null) {
                                  bloc.createFolder([...pathSnapshot.requireData, ...result]);
                                }
                              },
                              child: Text(FilesLocalizations.of(context).folderCreate),
                            ),
                            ElevatedButton(
                              onPressed: !(const ListEquality<String>().equals(originalPath, pathSnapshot.data))
                                  ? () => Navigator.of(context).pop(pathSnapshot.data)
                                  : null,
                              child: Text(FilesLocalizations.of(context).folderChoose),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
}
