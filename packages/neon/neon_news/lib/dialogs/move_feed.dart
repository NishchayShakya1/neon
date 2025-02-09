part of '../neon_news.dart';

class NewsMoveFeedDialog extends StatefulWidget {
  const NewsMoveFeedDialog({
    required this.folders,
    required this.feed,
    super.key,
  });

  final List<news.Folder> folders;
  final news.Feed feed;

  @override
  State<NewsMoveFeedDialog> createState() => _NewsMoveFeedDialogState();
}

class _NewsMoveFeedDialogState extends State<NewsMoveFeedDialog> {
  final formKey = GlobalKey<FormState>();

  news.Folder? folder;

  void submit() {
    if (formKey.currentState!.validate()) {
      Navigator.of(context).pop([folder?.id]);
    }
  }

  @override
  Widget build(final BuildContext context) => NeonDialog(
        title: Text(NewsLocalizations.of(context).feedMove),
        children: [
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                NewsFolderSelect(
                  folders: widget.folders,
                  value: widget.feed.folderId != null
                      ? widget.folders.singleWhere((final folder) => folder.id == widget.feed.folderId)
                      : null,
                  onChanged: (final f) {
                    setState(() {
                      folder = f;
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: submit,
                  child: Text(NewsLocalizations.of(context).feedMove),
                ),
              ],
            ),
          ),
        ],
      );
}
