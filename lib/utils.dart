import 'dart:math';

import 'package:finance_updated/finance_updated.dart';
import 'package:ml_linalg/vector.dart';

List<T> flatten<T>(Iterable<Iterable<T>> list) =>
    [for (var sublist in list) ...sublist];

Vector cumulativeSum(Vector vector) {
  List<num> cumulativeSumList = vector.toList();
  num sum = 0;
  for (int i = 0; i < vector.length; i++) {
    sum += vector[i];
    cumulativeSumList[i] = sum;
  }
  return Vector.fromList(cumulativeSumList);
}

Vector maximum(Vector a, Vector b) {
  List<num> result = List.filled(a.length, 0);
  for (int i = 0; i < result.length; i++) {
    result[i] = max(a[i], b[i]);
  }
  return Vector.fromList(result);
}

class FinanceVector extends Finance {
  Vector fvNper(
      {required num rate,
      required Vector nper,
      required num pmt,
      required num pv,
      bool end = true}) {
    return Vector.fromList(
        nper.map((i) => fv(rate: rate, nper: i, pmt: pmt, pv: pv)).toList());
  }

  Vector fvNperPv(
      {required num rate,
      required Vector nper,
      required num pmt,
      required Vector pv,
      bool end = true}) {
    List<num> result = List.filled(nper.length, 0.0);
    for (int i = 0; i < nper.length; i++) {
      result[i] = fv(rate: rate, nper: nper[i], pmt: pmt, pv: pv[i]);
    }
    return Vector.fromList(result);
  }

  Vector ppmtPer(
      {required num rate,
      required Vector per,
      required num nper,
      required num pv,
      bool end = true}) {
    return Vector.fromList(
        per.map((i) => ppmt(rate: rate, per: i, nper: nper, pv: pv)).toList());
  }

  Vector ipmtPer(
      {required num rate,
      required Vector per,
      required num nper,
      required num pv,
      bool end = true}) {
    return Vector.fromList(
        per.map((i) => ipmt(rate: rate, per: i, nper: nper, pv: pv)).toList());
  }
}
