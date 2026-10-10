"""Offline browser checks for the unified Following / Topics concept.

Run: python test_mockup.py
Requires Playwright and Chromium. Set CHROMIUM_PATH for a custom browser.
No HTTP, accounts, assets or Flutter project are used.
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import unittest

from playwright.sync_api import sync_playwright

HTML = Path(__file__).with_name('index.html').read_text(encoding='utf-8')


class TopicConceptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.playwright = sync_playwright().start()
        browser = os.environ.get('CHROMIUM_PATH') or shutil.which('chromium')
        options = {'headless': True, 'args': ['--no-sandbox']}
        if browser:
            options['executable_path'] = browser
        cls.browser = cls.playwright.chromium.launch(**options)

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()

    def setUp(self):
        self.context = self.browser.new_context(viewport={'width': 1440, 'height': 950})
        self.errors = []
        self.requests = []
        self.page = self.make_page()

    def tearDown(self):
        self.context.close()
        self.assertEqual(self.errors, [], 'Unexpected browser script errors')
        self.assertEqual(self.requests, [], 'No remote resources permitted')

    def make_page(self, stored=None):
        page = self.context.new_page()
        page.set_default_timeout(5000)
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

    def action(self, action, identifier=None, scope=''):
        selector = f'{scope} [data-action="{action}"]' if scope else f'[data-action="{action}"]'
        if identifier is not None:
            selector += f'[data-id="{identifier}"]'
        self.page.locator(selector).filter(visible=True).first.click()

    def open_folder(self, folder='f1'):
        self.action('open-folder', folder)
        self.page.wait_for_function('route.page === "folder"')

    def open_topic(self, topic='s1'):
        self.action('open-topic', topic)
        self.page.wait_for_function('route.page === "topic"')

    def edit_topic(self, topic='s1'):
        self.action('topic-menu', topic)
        self.action('edit-topic', topic)

    def test_single_following_entry_replaces_both_legacy_screens(self):
        self.assertEqual(self.page.locator('#sidebar .nav-item').count(), 1)
        self.assertEqual(self.page.locator('#sidebar .nav-item').inner_text().splitlines()[0], 'Following')
        self.assertIn('Topics', self.page.locator('#main').inner_text())
        self.assertEqual(self.page.locator('.folder-row').count(), 3)
        self.assertEqual(self.page.locator('.search-card').count(), 2)
        self.assertNotIn('Pinned searches', self.page.locator('#main').inner_text())
        self.assertNotIn('Following Feeds', self.page.locator('#main').inner_text())

    def test_folder_opens_topics_and_has_open_feed_in_actual_appbar(self):
        self.open_folder()
        self.assertEqual(self.page.locator('h1').inner_text(), 'Daily inspiration')
        self.assertEqual(self.page.locator('.search-card').count(), 2)
        self.assertEqual(self.page.locator('.folder-row').count(), 1)
        self.assertEqual(self.page.locator('.post').count(), 0)
        self.assertEqual(self.page.locator('#topbar [data-action="open-feed"]').count(), 1)
        self.assertEqual(self.page.locator('[role="tab"]').count(), 0)

    def test_topic_opens_normal_search_with_repeatable_pagination(self):
        self.open_folder()
        self.open_topic()
        self.assertEqual(self.page.locator('h1').inner_text(), 'Mosslight')
        self.assertIn('Normal search', self.page.locator('.summary-line').inner_text())
        self.assertEqual(self.page.locator('.post').count(), 12)
        self.action('load-more')
        self.assertEqual(self.page.locator('.post').count(), 24)
        self.action('load-more')
        self.assertEqual(self.page.locator('.post').count(), 36)
        self.assertEqual(self.page.evaluate('route.page'), 'topic')

    def test_folder_feed_is_alternative_view_not_independent_object(self):
        self.open_folder()
        self.action('open-feed', 'f1', '#topbar')
        self.page.wait_for_function('route.page === "feed"')
        self.assertEqual(self.page.evaluate('route.page'), 'feed')
        self.assertEqual(self.page.locator('.post').count(), 19)
        self.assertEqual(self.page.locator('.pagination-note').count(), 1)
        self.assertIn('not implemented in this concept', self.page.locator('.pagination-note').inner_text())
        self.assertEqual(self.page.locator('[data-action="load-more"]').count(), 0)
        self.action('open-folder', 'f1', '#topbar')
        self.page.wait_for_function('route.page === "folder"')
        self.assertEqual(self.page.locator('.search-card').count(), 2)

    def test_nested_topics_are_in_parent_feed_and_same_site_matches_merge(self):
        self.open_folder()
        self.assertEqual(self.page.evaluate('folderTopicIds("f1")'), ['s1', 's3', 's2', 's4'])
        self.action('open-feed', 'f1', '#topbar')
        self.page.wait_for_function('route.page === "feed"')
        self.assertEqual(self.page.locator('.post').count(), 19)
        for host in ['danbooru.donmai.us', 'gelbooru.com', 'rule34.xxx']:
            self.assertEqual(self.page.locator(f'.post[data-id="{host}:101"]').count(), 1)
        self.action('post', 'danbooru.donmai.us:101')
        self.assertIn('Mosslight, Night trains', self.page.locator('dialog').inner_text())

    def test_feed_profile_filter_and_upload_order_work(self):
        self.open_folder()
        self.action('open-feed', 'f1', '#topbar')
        self.action('profile', 'g')
        self.assertEqual(self.page.locator('.post').count(), 5)
        most_recent = self.page.locator('.post').first.get_attribute('data-id')
        self.page.select_option('#post-sort', 'oldest')
        self.assertEqual(self.page.locator('.post').last.get_attribute('data-id'), most_recent)

    def test_editing_a_topic_updates_all_folders_without_copying(self):
        self.open_folder()
        self.edit_topic('s1')
        self.assertIn('Shared topic', self.page.locator('dialog').inner_text())
        self.page.fill('[name="name"]', 'Mosslight updated')
        self.page.fill('[name="query"]', 'mosslight scenery rating:g')
        self.page.get_by_role('button', name='Save Topic', exact=True).click()
        self.assertEqual(self.page.evaluate('db.topics.length'), 9)
        self.assertEqual(self.page.evaluate('byId("s1").revision'), 1)
        self.action('nav', 'following')
        self.open_folder('f2')
        self.assertIn('Mosslight updated', self.page.locator('[data-row="s1"]').inner_text())

    def test_follow_reuses_identical_topic_and_links_to_folder(self):
        self.open_folder()
        self.action('follow-topic', 'f1')
        self.page.select_option('[name="profile"]', 'g')
        self.page.fill('[name="query"]', ' gesture_drawing  ')
        self.page.get_by_role('button', name='Follow topic', exact=True).last.click()
        self.assertEqual(self.page.evaluate('db.topics.length'), 9)
        self.assertTrue(self.page.evaluate('folderById("f1").topicIds.includes("s8")'))
        self.assertIn('reused', self.page.locator('#toast').inner_text())

    def test_new_topic_can_be_followed_at_root_then_opened(self):
        self.action('follow-topic')
        self.page.fill('[name="query"]', 'some_artist')
        self.page.fill('[name="name"]', 'Some artist')
        self.page.get_by_role('button', name='Follow topic', exact=True).last.click()
        self.assertEqual(self.page.evaluate('db.rootIds.length'), 3)
        self.assertIn('Some artist', self.page.locator('#main').inner_text())
        self.assertEqual(self.page.evaluate('db.topics.length'), 10)

    def test_link_existing_topic_does_not_remove_original_root_entry(self):
        self.open_folder()
        self.action('add-existing', 'f1')
        self.page.fill('#picker-filter', 'gesture')
        self.page.check('[name="topics"][value="s8"]')
        self.page.get_by_role('button', name='Add to folder', exact=True).click()
        self.assertEqual(self.page.evaluate('db.topics.length'), 9)
        self.assertTrue(self.page.evaluate('db.rootIds.includes("s8")'))
        self.assertTrue(self.page.evaluate('folderById("f1").topicIds.includes("s8")'))

    def test_remove_last_folder_link_keeps_topic_followed_at_root(self):
        self.open_folder('f3')
        self.action('topic-menu', 's7')
        self.action('remove-topic', 's7')
        self.action('confirm-remove-topic', 's7')
        self.assertTrue(self.page.evaluate('!!byId("s7")'))
        self.assertTrue(self.page.evaluate('db.rootIds.includes("s7")'))
        self.assertFalse(self.page.evaluate('folderById("f3").topicIds.includes("s7")'))

    def test_unfollow_is_explicit_and_removes_all_references(self):
        self.open_folder()
        self.action('topic-menu', 's1')
        self.action('unfollow', 's1')
        self.assertIn('2 folder', self.page.locator('dialog').inner_text())
        self.action('confirm-unfollow', 's1')
        self.assertFalse(self.page.evaluate('!!byId("s1")'))
        self.assertFalse(self.page.evaluate('db.folders.some(f=>f.topicIds.includes("s1"))'))

    def test_new_folder_has_feed_action_without_explicit_creation(self):
        self.action('new-folder')
        self.page.fill('[name="name"]', 'New folder')
        self.page.get_by_role('button', name='Create folder', exact=True).click()
        f_id = self.page.evaluate('db.folders.find(f=>f.name==="New folder").id')
        self.open_folder(f_id)
        self.assertEqual(self.page.locator('#topbar [data-action="open-feed"]').count(), 1)
        self.action('open-feed', f_id, '#topbar')
        self.assertIn('no topics', self.page.locator('.empty').inner_text().lower())

    def test_selection_supports_long_press_and_shift_range(self):
        self.open_folder()
        target=self.page.locator('[data-row="s1"] .search-open')
        box=target.bounding_box()
        self.page.mouse.move(box['x']+35,box['y']+25)
        self.page.mouse.down()
        self.page.wait_for_timeout(510)
        self.page.mouse.up()
        self.page.wait_for_timeout(650)
        self.assertIn('1 selected', self.page.locator('.selection-bar').inner_text())
        self.page.locator('[data-row="s3"] .search-open').click(modifiers=['Shift'])
        self.assertIn('2 selected', self.page.locator('.selection-bar').inner_text())
        self.page.keyboard.press('Escape')
        self.assertEqual(self.page.locator('.selection-bar').count(), 0)

    def test_outside_click_dismisses_context_menu_without_opening_topic(self):
        self.open_folder()
        box=self.page.locator('[data-row="s3"] .search-open').bounding_box()
        self.action('topic-menu', 's1')
        self.page.mouse.click(box['x']+40,box['y']+60)
        self.assertFalse(self.page.locator('dialog').evaluate('(d)=>d.open'))
        self.assertEqual(self.page.evaluate('route.page'), 'folder')

    def test_duplicate_query_edit_refused_without_modifying_topic(self):
        self.open_folder()
        self.edit_topic()
        self.page.fill('[name="query"]', 'train night')
        self.page.get_by_role('button', name='Save Topic', exact=True).click()
        self.assertIn('already followed', self.page.locator('#form-error').inner_text())
        self.page.keyboard.press('Escape')
        self.assertEqual(self.page.evaluate('byId("s1").query'), 'mosslight rating:g')

    def test_offline_scenario_is_scoped_to_one_profile(self):
        self.open_folder()
        self.action('open-feed', 'f1', '#topbar')
        self.page.select_option('#scenario', 'offline')
        self.assertIn('Cached posts remain visible', self.page.locator('.banner').inner_text())
        self.assertEqual(self.page.locator('.post').count(), 19)
        self.action('retry')
        self.assertEqual(self.page.locator('.banner').count(), 0)

    def test_topic_edits_round_trip_through_isolated_storage(self):
        self.open_folder()
        self.edit_topic()
        self.page.fill('[name="name"]', 'Persistent topic')
        self.page.get_by_role('button', name='Save Topic', exact=True).click()
        restored=self.make_page(self.page.evaluate('window.demoStorage'))
        self.assertEqual(restored.evaluate('byId("s1").name'), 'Persistent topic')
        self.assertEqual(restored.evaluate('db.topics.length'), 9)

    def test_user_supplied_name_is_escaped(self):
        self.open_folder()
        self.edit_topic()
        example='<img src=x onerror=alert(1)>'
        self.page.fill('[name="name"]', example)
        self.page.get_by_role('button', name='Save Topic', exact=True).click()
        self.assertIn(example, self.page.locator('[data-row="s1"]').inner_text())
        self.assertEqual(self.page.locator('img').count(), 0)

    def test_mobile_and_small_keyboard_viewports_remain_scrollable(self):
        self.page.set_viewport_size({'width': 320, 'height': 740})
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth>innerWidth'))
        self.open_folder()
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth>innerWidth'))
        self.action('follow-topic', 'f1')
        self.page.set_viewport_size({'width': 390, 'height': 420})
        self.page.fill('[name="query"]', 'flower')
        submit=self.page.get_by_role('button', name='Follow topic', exact=True).last
        submit.scroll_into_view_if_needed()
        submit.click()
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth>innerWidth'))
        self.assertEqual(self.page.evaluate('db.topics.length'), 10)


if __name__ == '__main__':
    unittest.main(verbosity=2)