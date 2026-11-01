// StateProvider lives in the legacy library in Riverpod 3.x.
// ignore: deprecated_member_use
import 'package:flutter_riverpod/legacy.dart';

/// Index of the selected tab in MainScaffold (0 = Home ... 3 = Profile).
final navigationProvider = StateProvider<int>((ref) => 0);
