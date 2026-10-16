import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Applies a navy/slate treatment to standard OSM tiles without a paid tile API.
Widget smartTransitDarkTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      -0.20332,
      -0.39916,
      -0.07752,
      0,
      183,
      -0.20930,
      -0.41090,
      -0.07980,
      0,
      199,
      -0.21528,
      -0.42264,
      -0.08208,
      0,
      219,
      0,
      0,
      0,
      1,
      0,
    ]),
    child: tileWidget,
  );
}
