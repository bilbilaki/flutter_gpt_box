part of '../view.dart';

Widget _buildIcloud(BuildContext context) {
  return CardX(
    child: ListTile(
      leading: const Icon(Icons.cloud),
      title: const Text('iCloud'),
      trailing: StoreSwitch(
        prop: PrefProps.webdavSync,
        validator: (p0) async {
          final res = await isNeedSignDrive();
          if (res) {
            context.showSnackBar(
              'You should first sign in with your google account',
            );
            return false;
          }
          return true;
        },
      ),
    ),
  );
}
