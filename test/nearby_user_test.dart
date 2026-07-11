import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/map/models/nearby_user.dart';

void main() {
  group('NearbyUser', () {
    test('fromFirestore가 문서 데이터를 모델로 변환한다', () {
      final user = NearbyUser.fromFirestore('user1', {
        'name': '김민준',
        'age': 27,
        'gender': 'm',
      });

      expect(user.id, 'user1');
      expect(user.name, '김민준');
      expect(user.age, 27);
      expect(user.gender, 'm');
    });

    test('fromFirestore가 누락 필드를 안전한 기본값으로 보정한다', () {
      final user = NearbyUser.fromFirestore('user2', {
        'age': 25.0, // num → int 변환
      });

      expect(user.name, '');
      expect(user.age, 25);
      expect(user.gender, '');
    });

    test('fromFirestore가 타입 불일치 필드에는 TypeError를 던진다', () {
      // 콘솔에서 age를 문자열로 잘못 입력한 경우 등.
      // 이 예외는 loadProfiles가 문서 단위로 걸러낸다.
      expect(
        () => NearbyUser.fromFirestore('bad', {'age': '27'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('toMap은 id를 제외한 필드만 직렬화한다', () {
      const user = NearbyUser(id: 'user3', name: '박지훈', age: 29, gender: 'm');

      expect(user.toMap(), {'name': '박지훈', 'age': 29, 'gender': 'm'});
    });

    test('같은 필드를 가진 인스턴스는 동등하다', () {
      const a = NearbyUser(id: 'user1', name: '김민준', age: 27, gender: 'm');
      const b = NearbyUser(id: 'user1', name: '김민준', age: 27, gender: 'm');
      const c = NearbyUser(id: 'user1', name: '김민준', age: 28, gender: 'm');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
