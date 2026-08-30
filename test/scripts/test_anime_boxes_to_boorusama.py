import csv
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / 'scripts'))

from anime_boxes_to_boorusama import ConversionError, convert_csv, main, write_json


def favorite_row(
    *,
    server_id='2',
    source_url='https://danbooru.donmai.us/posts/123/',
    post_id='123',
    timestamp='8/21/26 14:33',
):
    return [
        server_id,
        post_id,
        source_url,
        '850',
        '1321',
        'https://example.com/sample.jpg',
        '0',
        '0',
        'https://example.com/thumbnail.jpg',
        '1957',
        '3042',
        'https://example.com/original.jpg',
        '1957',
        '3042',
        'https://example.com/original.jpg',
        '1girl blue_hair',
        '1girl blue_hair',
        'artist_name,character_name',
        '0123456789abcdef0123456789abcdef',
        'https://artist.example/source',
        '0',
        '0',
        'e',
        '0',
        '0',
        '0',
        timestamp,
    ]


def write_anime_boxes_export(path, favorites):
    with path.open('w', encoding='utf-8', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['#Meta'])
        writer.writerow(['5', '1.0', 'Anime boxes (Android)', '2.0.7', '8/21/26 15:53'])
        writer.writerow(['#Servers'])
        writer.writerow(['0', '2', 'https://danbooru.donmai.us', 'Danbooru'])
        writer.writerow(['0', '99', 'https://unknown.example', 'Unknown'])
        writer.writerow(['#Favorites'])
        writer.writerows(favorites)


class AnimeBoxesConverterTest(unittest.TestCase):
    def test_converts_favorites_and_assigns_them_to_the_named_group(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / 'anime_boxes.csv'
            write_anime_boxes_export(input_path, [favorite_row()])

            payload = convert_csv(input_path, group_name='Anime Favorites')

        bookmark = payload['data'][0]
        self.assertEqual(payload['version'], 1)
        self.assertEqual(bookmark['id'], 1)
        self.assertEqual(bookmark['booruId'], 20)
        self.assertEqual(bookmark['postId'], 123)
        self.assertEqual(bookmark['width'], 1957.0)
        self.assertEqual(bookmark['height'], 3042.0)
        self.assertEqual(bookmark['format'], 'jpg')
        self.assertEqual(bookmark['createdAt'], '2026-08-21T14:33:00')
        self.assertIn('blue_hair', bookmark['tags'])
        self.assertEqual(payload['groups'], [
            {'name': 'Anime Favorites', 'bookmarkIds': [1]},
        ])

    def test_unknown_hosts_require_an_explicit_booru_id_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / 'anime_boxes.csv'
            write_anime_boxes_export(
                input_path,
                [favorite_row(
                    server_id='99',
                    source_url='https://unknown.example/posts/456',
                    post_id='456',
                )],
            )

            with self.assertRaisesRegex(ConversionError, 'booru-id-map'):
                convert_csv(input_path, group_name='Imported')

            payload = convert_csv(
                input_path,
                group_name='Imported',
                booru_id_map={'unknown.example': 30},
            )

        self.assertEqual(payload['data'][0]['booruId'], 30)

    def test_writes_importable_json(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / 'anime_boxes.csv'
            output_path = Path(directory) / 'boorusama.json'
            write_anime_boxes_export(input_path, [favorite_row()])

            write_json(
                output_path,
                convert_csv(input_path, group_name='Imported'),
            )

            with output_path.open(encoding='utf-8') as file:
                payload = json.load(file)

        self.assertEqual(payload['data'][0]['originalUrl'], 'https://example.com/original.jpg')
        self.assertEqual(payload['groups'][0]['bookmarkIds'], [1])

    def test_cli_does_not_contaminate_json_when_stdout_is_redirected(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / 'anime_boxes.csv'
            output_path = Path(directory) / 'boorusama.json'
            write_anime_boxes_export(input_path, [favorite_row()])

            stdout = io.StringIO()
            with redirect_stdout(stdout):
                exit_code = main([
                    str(input_path),
                    str(output_path),
                    '--group-name',
                    'Imported',
                ])

            with output_path.open(encoding='utf-8') as file:
                payload = json.load(file)

        self.assertEqual(exit_code, 0)
        self.assertEqual(stdout.getvalue(), '')
        self.assertEqual(payload['groups'][0]['name'], 'Imported')


if __name__ == '__main__':
    unittest.main()
