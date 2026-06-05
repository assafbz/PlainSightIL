import 'package:flutter_test/flutter_test.dart';
import 'package:plainsight/features/datasets/local_market_bonds/data/models/local_market_bond_model.dart';

void main() {
  group('LocalMarketBondRecordModel Tests', () {
    test('fromMap parses safely', () {
      final map = {
        'id': '1',
        '_id': 1,
        'issuanceDate': '2026-06-02T00:00:00.000Z',
        'bondType': {'he': 'ממשלתית', 'en': 'Government'},
        'series': 1227784,
        'actualTermToMaturity': 9.4,
        'originalTermToMaturity': 10.0,
        'redemptionDate': '2035-10-31T00:00:00.000Z',
        'coupon': 4.15,
        'offeredQuantity': 106.0,
        'purchasedQuantity': 105.8,
        'additionalPurchased': -0.1,
        'averagePrice': 105.73,
        'cutoffPrice': 105.73,
        'totalFunding': 111.9,
        'demandedAmount': 105.8,
        'coverRatio': 1.0,
        'grossAvgYield': 3.73,
        'grossCutoffYield': 3.73,
        'createdAt': '2026-06-04T12:00:00Z',
        'updatedAt': '2026-06-04T12:00:00Z',
        'lastUpdated': '2026-06-04T12:00:00Z',
      };

      final model = LocalMarketBondRecordModel.fromMap(map);
      expect(model.id, '1');
      expect(model.idNum, 1);
      expect(model.issuanceDate, '2026-06-02T00:00:00.000Z');
      expect(model.bondType['en'], 'Government');
      expect(model.series, 1227784);
      expect(model.actualTermToMaturity, 9.4);
      expect(model.originalTermToMaturity, 10.0);
      expect(model.redemptionDate, '2035-10-31T00:00:00.000Z');
      expect(model.coupon, 4.15);
      expect(model.offeredQuantity, 106.0);
      expect(model.purchasedQuantity, 105.8);
      expect(model.additionalPurchased, -0.1);
      expect(model.averagePrice, 105.73);
      expect(model.cutoffPrice, 105.73);
      expect(model.totalFunding, 111.9);
      expect(model.demandedAmount, 105.8);
      expect(model.coverRatio, 1.0);
      expect(model.grossAvgYield, 3.73);
      expect(model.grossCutoffYield, 3.73);
      expect(model.createdAt, '2026-06-04T12:00:00Z');
      expect(model.updatedAt, '2026-06-04T12:00:00Z');
      expect(model.lastUpdated, '2026-06-04T12:00:00Z');
    });

    test('toMap serializes correctly', () {
      final model = LocalMarketBondRecordModel(
        id: '1',
        idNum: 1,
        issuanceDate: '2026-06-02T00:00:00.000Z',
        bondType: const {'he': 'ממשלתית', 'en': 'Government'},
        series: 1227784,
        actualTermToMaturity: 9.4,
        originalTermToMaturity: 10.0,
        redemptionDate: '2035-10-31T00:00:00.000Z',
        coupon: 4.15,
        offeredQuantity: 106.0,
        purchasedQuantity: 105.8,
        additionalPurchased: -0.1,
        averagePrice: 105.73,
        cutoffPrice: 105.73,
        totalFunding: 111.9,
        demandedAmount: 105.8,
        coverRatio: 1.0,
        grossAvgYield: 3.73,
        grossCutoffYield: 3.73,
        createdAt: '2026-06-04T12:00:00Z',
        updatedAt: '2026-06-04T12:00:00Z',
        lastUpdated: '2026-06-04T12:00:00Z',
      );

      final map = model.toMap();
      expect(map['id'], '1');
      expect(map['_id'], 1);
      expect(map['issuanceDate'], '2026-06-02T00:00:00.000Z');
      expect(map['bondType'], const {'he': 'ממשלתית', 'en': 'Government'});
      expect(map['series'], 1227784);
      expect(map['actualTermToMaturity'], 9.4);
      expect(map['originalTermToMaturity'], 10.0);
      expect(map['redemptionDate'], '2035-10-31T00:00:00.000Z');
      expect(map['coupon'], 4.15);
      expect(map['offeredQuantity'], 106.0);
      expect(map['purchasedQuantity'], 105.8);
      expect(map['additionalPurchased'], -0.1);
      expect(map['averagePrice'], 105.73);
      expect(map['cutoffPrice'], 105.73);
      expect(map['totalFunding'], 111.9);
      expect(map['demandedAmount'], 105.8);
      expect(map['coverRatio'], 1.0);
      expect(map['grossAvgYield'], 3.73);
      expect(map['grossCutoffYield'], 3.73);
      expect(map['createdAt'], '2026-06-04T12:00:00Z');
      expect(map['updatedAt'], '2026-06-04T12:00:00Z');
      expect(map['lastUpdated'], '2026-06-04T12:00:00Z');
    });
  });
}
