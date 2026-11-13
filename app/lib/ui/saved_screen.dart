import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/tax_update.dart';
import 'update_card.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.settings,
      builder: (context, _) {
        final ids = scope.settings.saved.toList();
        if (ids.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Tap the bookmark on any update to keep it here.', textAlign: TextAlign.center),
            ),
          );
        }
        return FutureBuilder<List<TaxUpdate?>>(
          future: Future.wait(ids.map(scope.repo.byId)),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!.whereType<TaxUpdate>().toList();
            return ListView(children: [for (final u in items) UpdateCard(update: u)]);
          },
        );
      },
    );
  }
}
