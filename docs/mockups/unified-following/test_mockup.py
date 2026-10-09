"""Browser checks for the offline concept; no Flutter or application data is used.

Run: python test_mockup.py
Requires Playwright and Chromium. Set CHROMIUM_PATH to override the executable.
The HTML is rendered in memory; a small storage double isolates each test.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import unittest

from playwright.sync_api import sync_playwright

HTML = Path(__file__).with_name('index.html').read_text(encoding='utf-8')


class FollowingConceptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.playwright = sync_playwright().start()
        executable = os.environ.get('CHROMIUM_PATH') or shutil.which('chromium')
        options = {'headless': True}
        if executable:
            options['executable_path'] = executable
        cls.browser = cls.playwright.chromium.launch(**options)

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()

    def make_page(self, stored=None):
        page = self.context.new_page()
        page.set_default_timeout(4000)
        page.on('pageerror', lambda error: self.errors.append(str(error)))
        page.on('request', lambda request: self.requests.append(request.url))
        page.evaluate('''stored => {
            window.demoStorage = stored || {};
            Object.defineProperty(window, 'localStorage', {value: {
                getItem: key => window.demoStorage[key] ?? null,
                setItem: (key, value) => { window.demoStorage[key] = String(value); },
                removeItem: key => { delete window.demoStorage[key]; }
            }});
        }''', stored)
        page.set_content(HTML)
        return page

    def setUp(self):
        self.context = self.browser.new_context(viewport={'width': 1440, 'height': 1000})
        self.errors = []
        self.requests = []
        self.page = self.make_page()

    def tearDown(self):
        self.context.close()
        self.assertEqual(self.errors, [], 'Unexpected browser errors')
        self.assertEqual(self.requests, [], 'The demo must not request remote resources')

    def action(self, action, identifier=None):
        selector = f'[data-action="{action}"]'
        if identifier is not None:
            selector += f'[data-id="{identifier}"]'
        self.page.locator(selector).filter(visible=True).first.click()

    def open_folder(self, identifier='f1', view='posts'):
        self.action('open-feed', identifier)
        self.page.wait_for_function('route.page === "folder"')
        if view == 'searches':
            self.action('tab', 'searches')

    def edit(self, identifier='s1'):
        self.action('search-menu', identifier)
        self.action('edit-search', identifier)

    def test_overview_exposes_the_existing_pinned_search_library(self):
        self.assertEqual(self.page.locator('.feed-card').count(), 2)
        self.assertIn('Pinned searches', self.page.locator('#sidebar').inner_text())
        self.assertNotIn('Saved searches', self.page.locator('body').inner_text())
        self.action('nav', 'library')
        self.action('library-tab', 'all')
        self.assertEqual(self.page.locator('.search-card').count(), 8)

    def test_mixed_posts_keep_cross_site_id_collisions_and_merge_same_site_matches(self):
        self.open_folder()
        self.assertEqual(self.page.locator('.post').count(), 19)
        for host in ['danbooru.donmai.us', 'gelbooru.com', 'rule34.xxx']:
            self.assertEqual(self.page.locator(f'.post[data-id="{host}:101"]').count(), 1)
        self.action('post', 'danbooru.donmai.us:101')
        detail = self.page.locator('dialog').inner_text()
        self.assertIn('Mosslight, Night trains', detail)

    def test_profile_filter_and_upload_order_are_functional(self):
        self.open_folder()
        self.action('profile', 'r')
        self.assertEqual(self.page.locator('.post').count(), 5)
        self.assertTrue(all(key.startswith('rule34.xxx:') for key in
                            self.page.locator('.post').evaluate_all('(els)=>els.map(e=>e.dataset.id)')))
        newest = self.page.locator('.post').first.get_attribute('data-id')
        self.page.select_option('#post-sort', 'oldest')
        self.assertEqual(self.page.locator('.post').last.get_attribute('data-id'), newest)

    def test_shared_edit_updates_other_feeds_without_copying_searches(self):
        self.open_folder(view='searches')
        self.edit()
        self.assertIn('2 folders · 2 feeds', self.page.locator('dialog').inner_text())
        self.page.fill('[name="name"]', 'Mosslight updated')
        self.page.fill('[name="query"]', 'mosslight scenery rating:g')
        self.page.get_by_role('button', name='Save changes', exact=True).click()
        self.action('open-feed', 'f2')
        self.action('tab', 'searches')
        self.assertIn('Mosslight updated', self.page.locator('[data-row="s1"]').inner_text())
        self.assertIn('mosslight scenery rating:g', self.page.locator('[data-row="s1"]').inner_text())
        self.assertEqual(self.page.evaluate('db.searches.length'), 8)
        self.assertEqual(self.page.evaluate('byId("s1").revision'), 1)

    def test_follow_reuses_an_identical_pinned_search(self):
        self.action('follow')
        self.page.select_option('[name="profile"]', 'g')
        self.page.fill('[name="query"]', '  gesture_drawing  ')
        self.page.check('[name="destinations"][value="f1"]')
        self.page.get_by_role('button', name='Follow', exact=True).click()
        self.assertEqual(self.page.evaluate('db.searches.length'), 8)
        self.assertTrue(self.page.evaluate('folderById("f1").searchIds.includes("s8")'))
        self.assertIn('reused', self.page.locator('#toast').inner_text())

    def test_add_existing_links_an_original_record(self):
        self.open_folder(view='searches')
        self.action('add-existing', 'f1')
        self.page.fill('#picker-filter', 'geometry')
        self.page.check('[name="searches"][value="s5"]')
        self.page.get_by_role('button', name='Add to folder', exact=True).click()
        self.assertEqual(self.page.evaluate('db.searches.length'), 8)
        self.assertEqual(self.page.evaluate('memberships("s5").length'), 2)

    def test_create_feed_reuses_folder_and_removing_feed_preserves_it(self):
        self.action('create-feed')
        self.page.select_option('#feed-folder', 'f3')
        self.page.get_by_role('button', name='Create feed', exact=True).last.click()
        self.page.wait_for_function('route.id === "f3"')
        self.assertEqual(self.page.evaluate('db.folders.length'), 4)
        self.assertEqual(self.page.locator('.post').count(), 5)
        self.action('folder-menu', 'f3')
        self.action('remove-feed', 'f3')
        self.action('confirm-remove-feed', 'f3')
        self.assertFalse(self.page.evaluate('folderById("f3").feed'))
        self.assertEqual(self.page.evaluate('db.searches.length'), 8)
        self.assertEqual(self.page.evaluate('folderById("f3").searchIds'), ['s7'])

    def test_new_empty_feed_can_receive_a_new_search(self):
        self.action('create-feed')
        self.page.fill('[name="name"]', 'Weekend discoveries')
        self.page.get_by_role('button', name='Create feed', exact=True).last.click()
        self.page.wait_for_function('route.page === "folder"')
        self.assertIn('first search', self.page.locator('.empty').inner_text())
        self.action('new-search')
        self.page.fill('[name="query"]', 'forest waterfall')
        self.page.fill('[name="name"]', 'Forest walks')
        self.page.get_by_role('button', name='Pin search', exact=True).click()
        self.assertEqual(self.page.locator('.post').count(), 5)
        self.assertEqual(self.page.evaluate('db.searches.length'), 9)

    def test_removing_a_link_does_not_delete_a_shared_search(self):
        self.open_folder(view='searches')
        self.action('search-menu', 's1')
        self.action('remove-search', 's1')
        self.action('confirm-remove-search', 's1')
        self.assertTrue(self.page.evaluate('!!byId("s1")'))
        self.assertFalse(self.page.evaluate('folderById("f1").searchIds.includes("s1")'))
        self.assertTrue(self.page.evaluate('folderById("f2").searchIds.includes("s1")'))

    def test_explicit_delete_everywhere_removes_all_references(self):
        self.open_folder(view='searches')
        self.action('search-menu', 's1')
        self.action('delete-search', 's1')
        self.assertIn('2 folders and 2 feeds', self.page.locator('dialog').inner_text())
        self.action('confirm-delete-search', 's1')
        self.assertFalse(self.page.evaluate('!!byId("s1")'))
        self.assertFalse(self.page.evaluate('db.folders.some(f=>f.searchIds.includes("s1"))'))

    def test_long_press_and_shift_click_support_selection_without_navigation(self):
        self.open_folder(view='searches')
        target = self.page.locator('[data-row="s1"] .search-open')
        box = target.bounding_box()
        self.page.mouse.move(box['x'] + 30, box['y'] + 25)
        self.page.mouse.down()
        self.page.wait_for_timeout(510)
        self.page.mouse.up()
        self.page.wait_for_timeout(650)
        self.assertIn('1 selected', self.page.locator('.selection-bar').inner_text())
        self.page.locator('[data-row="s3"] .search-open').click(modifiers=['Shift'])
        self.assertIn('2 selected', self.page.locator('.selection-bar').inner_text())
        self.assertEqual(self.page.evaluate('route.page'), 'folder')
        self.assertEqual(self.page.locator('#search-filter').count(), 0)
        self.page.keyboard.press('Escape')
        self.assertEqual(self.page.locator('.selection-bar').count(), 0)

    def test_outside_menu_click_only_dismisses_the_menu(self):
        self.open_folder(view='searches')
        target = self.page.locator('[data-row="s3"] .search-open').bounding_box()
        self.action('search-menu', 's1')
        self.page.mouse.click(target['x'] + 30, target['y'] + 60)
        self.assertFalse(self.page.locator('dialog').evaluate('(el)=>el.open'))
        self.assertEqual(self.page.evaluate('route.page'), 'folder')

    def test_cancel_and_duplicate_edit_do_not_mutate_the_original(self):
        self.open_folder(view='searches')
        self.edit()
        self.page.fill('[name="query"]', 'train night')
        self.page.get_by_role('button', name='Save changes', exact=True).click()
        self.assertIn('already pinned', self.page.locator('#form-error').inner_text())
        self.page.keyboard.press('Escape')
        self.assertEqual(self.page.evaluate('byId("s1").query'), 'mosslight rating:g')

    def test_refresh_failure_keeps_other_profiles_and_cached_posts_visible(self):
        self.open_folder()
        self.page.select_option('#scenario', 'offline')
        self.assertIn('Cached posts remain visible', self.page.locator('.banner').inner_text())
        self.assertEqual(self.page.locator('.post').count(), 19)
        self.action('retry')
        self.assertEqual(self.page.locator('.banner').count(), 0)

    def test_nested_folder_sources_and_profile_filtered_folder_lists(self):
        self.open_folder()
        self.assertEqual(self.page.evaluate('folderSearchIds("f1")'), ['s1', 's3', 's2', 's4'])
        self.action('nav', 'library')
        self.action('profile', 'g')
        self.assertEqual(self.page.locator('.folder-open[data-id="f3"]').count(), 0)
        self.assertEqual(self.page.locator('.folder-open[data-id="f1"]').count(), 1)

    def test_persistence_round_trip_with_an_isolated_storage_double(self):
        self.open_folder(view='searches')
        self.edit()
        self.page.fill('[name="name"]', 'Persisted name')
        self.page.get_by_role('button', name='Save changes', exact=True).click()
        stored = self.page.evaluate('window.demoStorage')
        restored = self.make_page(stored)
        self.assertEqual(restored.evaluate('byId("s1").name'), 'Persisted name')
        self.assertEqual(restored.evaluate('db.searches.length'), 8)

    def test_mobile_large_text_and_reduced_height_dialog_stay_usable(self):
        self.open_folder(view='searches')
        self.page.set_viewport_size({'width': 320, 'height': 740})
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth > innerWidth'))
        self.page.evaluate('''() => {
            const items = [...document.querySelectorAll('#main *, #topbar *')].map(el =>
                [el, parseFloat(getComputedStyle(el).fontSize)]);
            items.forEach(([el, size]) => { el.style.fontSize = (size * 1.5) + 'px'; });
        }''')
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth > innerWidth'))
        self.edit()
        self.page.set_viewport_size({'width': 390, 'height': 420})
        self.page.fill('[name="name"]', 'Compact editor')
        submit = self.page.get_by_role('button', name='Save changes', exact=True)
        submit.scroll_into_view_if_needed()
        submit.click()
        self.assertEqual(self.page.evaluate('byId("s1").name'), 'Compact editor')
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth > innerWidth'))

    def test_user_text_is_rendered_as_text_not_markup(self):
        self.open_folder(view='searches')
        self.edit()
        text = '<img src=x onerror=alert(1)>'
        self.page.fill('[name="name"]', text)
        self.page.get_by_role('button', name='Save changes', exact=True).click()
        self.assertIn(text, self.page.locator('[data-row="s1"]').inner_text())
        self.assertEqual(self.page.locator('img').count(), 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
