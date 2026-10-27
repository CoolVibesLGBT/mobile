import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/profile_data.dart';

void main() {
  test(
    'cover resolves current media and legacy fields without letting an empty object hide it',
    () {
      final cover = {
        'file': {
          'variants': {
            'image': {
              'large': {'url': '/static/cover.jpg'},
            },
          },
        },
      };
      expect(
        profileCover({'cover': cover, 'banner_url': '/static/old.jpg'}),
        assetUrl('/static/cover.jpg'),
      );
      for (final key in [
        'cover_image',
        'cover_photo',
        'cover_image_url',
        'cover_url',
        'banner_url',
      ]) {
        expect(
          profileCover({'cover': {}, key: '/static/cover.jpg'}),
          assetUrl('/static/cover.jpg'),
        );
      }
      expect(profileCover({'cover': {}, 'cover_url': ''}), isNull);
      expect(profileCover({'cover': '  ', 'cover_url': ''}), isNull);
    },
  );
  test('cover prefers original photo over server-composited variants', () {
    final file = <String, dynamic>{
      'url': '/static/original.jpg',
      'variants': {
        'image': {
          'original': {'url': '/static/original-variant.jpg'},
          'large': {'url': '/static/blurred-large.webp'},
          'small': {'url': '/static/blurred-small.webp'},
        },
      },
    };
    final user = {
      'cover': {'file': file},
    };
    expect(profileCover(user), assetUrl('/static/original-variant.jpg'));
    final images = object(object(file['variants'])['image']);
    images.remove('original');
    file['variants'] = {'image': images};
    expect(profileCover(user), assetUrl('/static/original.jpg'));
    file.remove('url');
    expect(profileCover(user), assetUrl('/static/blurred-large.webp'));
  });
  test(
    'profile identity unwraps payloads and handles numeric IDs and normalized names',
    () {
      expect(
        profileBelongsTo(
          {
            'data': {
              'profile': {'public_id': '12'},
            },
          },
          {
            'user': {'public_id': 12},
          },
        ),
        isTrue,
      );
      expect(
        profileBelongsTo({'username': ' DENIZ '}, {'nickname': 'deniz'}),
        isTrue,
      );
      expect(
        profileBelongsTo({'public_id': '13'}, {'public_id': '12'}),
        isFalse,
      );
      expect(profileBelongsTo({}, {}), isFalse);
    },
  );
  test('activity visibility matches the existing profile privacy rules', () {
    bool visible(
      Map<String, dynamic> user, {
      bool own = false,
      bool authenticated = true,
    }) => canViewProfileActivity(user, own: own, authenticated: authenticated);
    expect(visible({}), isTrue);
    expect(visible({}, authenticated: false), isFalse);
    expect(visible({'privacy_level': 'private'}, own: true), isTrue);
    expect(visible({'privacy_level': 'followers_only'}), isFalse);
    expect(
      visible({'privacy_level': 'followers_only', 'is_following': '1'}),
      isTrue,
    );
    expect(
      visible({'privacy_level': 'friends_only', 'is_following': true}),
      isFalse,
    );
    expect(
      visible({
        'privacy_level': 'mutuals_only',
        'is_following': true,
        'is_followed_by': true,
      }),
      isTrue,
    );
    expect(visible({'privacy_level': 'public', 'is_blocking': true}), isFalse);
    expect(visible({'privacy_level': 'new-unknown-policy'}), isFalse);
  });
}
