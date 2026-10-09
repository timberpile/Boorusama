#!/usr/bin/env python3
"""Offline Chromium acceptance checks for the HTML lab, not Flutter/device tests.

Requires Python playwright and Chromium. Defaults to /usr/bin/chromium; override
with --browser. set_content keeps fixtures wholly offline and works in sandboxes
that do not permit local HTTP navigation. Browser-history state still runs.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]

def standalone() -> str:
    html = (ROOT / 'index.html').read_text()
    html = html.replace('<link rel="stylesheet" href="styles.css">', '<style>' + (ROOT / 'styles.css').read_text() + '</style>')
    scripts = ['model.js', 'app.js', 'views.js', 'dialogs.js', 'actions.js']
    for script in scripts:
        html = html.replace('<script defer src="' + script + '"></script>', '')
    inline = ''.join('<script>' + (ROOT / script).read_text() + '</script>' for script in scripts)
    return html.replace('</body>', inline + '</body>')

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--browser', default='/usr/bin/chromium')
    parser.add_argument('--screenshots', type=Path)
    parser.add_argument('--group', choices=['all', 'navigation', 'editing', 'layout'], default='all', help='Split isolated checks for short-lived execution environments')
    args = parser.parse_args()
    completed = []
    test_number = 0
    with sync_playwright() as pw:
        browser = pw.chromium.launch(executable_path=args.browser, args=['--no-sandbox', '--disable-dev-shm-usage'])
        page = browser.new_page(viewport={'width': 1440, 'height': 1200})
        errors, requests = [], []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('request', lambda request: requests.append(request.url))
        page.set_default_timeout(3500)
        page.set_content(standalone())
        def read(expression):
            return page.evaluate('() => {const m=window.__navigationLab.model, ui=window.__navigationLab.ui;return (' + expression + ');}')
        def check(condition, message):
            assert condition, message
        def click(action, suffix=''):
            scope = page.locator('#modal') if page.locator('#modal').is_visible() else page
            scope.locator('[data-action="' + action + '"]' + suffix + ':visible').first.click()
            page.wait_for_timeout(20)
        def scenario(value):
            page.locator('#scenario').select_option(value)
            page.wait_for_timeout(20)
        def reset(concept='B'):
            if page.locator('#modal').is_visible():
                page.keyboard.press('Escape')
                page.wait_for_timeout(25)
            page.locator('button[data-concept="' + concept + '"]').click()
            page.locator('#reset').click()
            page.wait_for_timeout(25)
        def test(name, fn):
            nonlocal test_number
            test_number += 1
            group = 'navigation' if test_number <= 6 else 'editing' if test_number <= 12 else 'layout'
            if args.group not in ('all', group):
                return
            fn()
            check(not errors, 'Browser errors: ' + str(errors))
            completed.append(name)
            print('PASS', name, flush=True)

        for concept in ['A', 'B', 'C']:
            def journey(concept=concept):
                reset(concept)
                scenario('nested')
                click('menu')
                click('nav', '[data-section="browse"]')
                click('menu')
                click('nav', '[data-section="bookmarks"]')
                check(read('m.route.group') == 'scenery', 'nested group must survive switching')
                click('back')
                check(read('m.route.folder') == 'collections', 'Back returns to immediate parent')
                click('back')
                check(read('m.route.folder') is None, 'Back reaches collection root')
            test(concept + ' restores nested group through global navigation', journey)

        def cross_profile():
            reset(); scenario('pins'); click('pin-open', '[data-id="p3"]')
            check(read('m.nav.profile') == 'gel', 'pin activates owner')
            check(read('m.route.query') == 'original scenery', 'exact stored query')
            click('back');check(read('m.nav.section') == 'following', 'Back returns to pin collection')
            click('pin-folder', '[data-id="worlds"]');click('pin-folder', '[data-id="atmospheres"]')
            click('following-tab', '[data-page="feeds"]');click('feed-open', '[data-id="f1"]')
            click('following-tab', '[data-page="pins"]')
            check(read('m.route.folder') == 'atmospheres', 'nested pin folder retained')
            click('following-tab', '[data-page="feeds"]');check(read('m.route.id') == 'f1', 'feed position retained')
        test('cross-profile pin and independent nested Following tabs', cross_profile)

        def viewer_pending():
            reset();scenario('nested')
            key=read('m.visiblePosts()[0].key')
            click('post', '[data-id="'+key+'"]');click('viewer-mark')
            check(read('m.viewedPost.bookmarked') is True, 'grid snapshot remains marked')
            check(read('m.isMarked(m.viewedPost)') is False, 'viewer reflects pending removal')
            click('viewer-info');click('close-modal')
            check(read('m.viewer!==null && Object.keys(m.pending).length===1'), 'info close must not commit viewer changes')
            click('viewer-close')
            check(read('m.viewer') is None, 'viewer closed')
            check(read('m.posts.find(p=>p.key==='+json.dumps(key)+').bookmarked') is False, 'removal commits when viewer closes')
        test('viewer mutation commits only when viewer closes, not its info dialog', viewer_pending)

        def focus_outside():
            reset();click('menu')
            box=page.locator('#modal').bounding_box()
            page.mouse.click(box['x'] + box['width'] + 8, box['y'] + 140)
            page.wait_for_timeout(60)
            check(read('ui.modal') is None, 'outside click closes menu')
            check(read('m.viewer') is None, 'outside click must not open a post underneath')
            check(page.evaluate('document.activeElement.dataset.action') == 'menu', 'focus returns to menu trigger')
        test('outside tap is consumed and keyboard focus returns', focus_outside)

        def dirty_form():
            reset();click('search');page.locator('#field-query').fill('night scenery')
            click('close-modal');check(read('ui.modal.type') == 'discard', 'closing dirty search guarded')
            click('keep-editing');check(page.locator('#field-query').input_value()=='night scenery', 'draft retained')
            page.evaluate('history.back()');page.wait_for_timeout(60)
            check(read('ui.modal.type') == 'discard', 'browser Back also guards dirty form')
            click('discard-edit');check(read('ui.modal') is None,'draft dismissed')
            check(read('m.route.page')=='browse','no query submitted by discard')
        test('dirty form retains draft; explicit close and Browser Back guard it', dirty_form)

        def selection():
            reset();scenario('selection');check(read('m.selection.length')==3,'three selected fixture posts')
            check(page.locator('.bottom-nav:visible').count()==0,'bulk toolbar replaces navigation')
            click('move');check(page.locator('#modal [data-action="move-destination"][data-id="collections"]').count()==0,'folder not a post assignment target')
            click('move-destination','[data-id="scenery"]');check(read('m.selection.length')==0,'move exits selection')
            scenario('nested');click('back');click('back');click('item-menu','[data-id="collections"]');click('select-item','[data-id="collections"]')
            check(page.locator('[data-action="group-open"][data-id="all"]').is_disabled(),'All disabled in group selection')
            check(page.locator('[data-action="group-open"][data-id="none"]').is_disabled(),'No group disabled in selection')
            click('clear-selection')
        test('selection replaces navigation and distinguishes views, folders and groups', selection)

        def create_pin_tree():
            reset();scenario('pins');click('create-menu');click('create-pin')
            page.locator('#field-name').fill('Test search');page.locator('#field-query').fill('scenery original test')
            page.locator('input[name=folder][value=atmospheres]').check()
            check(page.locator('.folder-picker .tree-indent input[value=atmospheres]').count()==1, 'picker represents nesting')
            page.locator('form[data-form=pin] button[type=submit]').click();page.wait_for_timeout(25)
            check(read('m.pins.at(-1).folder')=='atmospheres','new pin saved in nested folder')
        test('pin form offers a real folder tree and saves its selection', create_pin_tree)

        def filter_restore():
            reset();scenario('pins');page.locator('[data-local-filter]').fill('Sketchbook')
            click('nav','[data-section="bookmarks"]');click('nav','[data-section="following"]')
            check(page.locator('[data-local-filter]').input_value()=='Sketchbook','filter survives destination switch')
            check(page.locator('[data-action=pin-open]:visible').count()==1,'restored filter applied')
        test('local filter and collection location survive task switches',filter_restore)

        def workspace():
            reset('C');click('spaces');click('switch-space','[data-id="s2"]');check(read('m.route.id')=='f1','feed workspace opened')
            click('spaces');click('switch-space','[data-id="s3"]');check(read('m.route.group')=='inspiration','bookmark workspace opened')
            click('spaces');click('create-space');page.locator('#field-name').fill('Comparison');page.locator('form[data-form=space] button[type=submit]').click();page.wait_for_timeout(25)
            check(read('m.spaces.length')==4,'workspace created')
            click('profiles');click('choose-profile','[data-id="gel"]');click('spaces');click('switch-space','[data-id="s1"]')
            check(read('m.nav.profile')=='personal','original workspace retains its profile')
            page.keyboard.press('Control+k');page.wait_for_timeout(60);check(read('ui.modal.type')=='jump','keyboard jump available')
            click('close-modal')
        test('workspaces keep profiles and histories; command jump is reachable',workspace)

        def states():
            reset()
            for state,title in [('guest','needs a site account'),('offline','Offline'),('empty','Make room'),('no-profile','Your collection starts'),('missing','This source is unavailable')]:
                scenario(state);check(title in page.locator('#screen').inner_text(),'expected explicit '+state+' state')
            scenario('browse')
        test('guest, offline, empty, no-profile and missing-owner states',states)

        def layouts():
            reset()
            for concept in ['A','B','C']:
                reset(concept)
                for width,size in [(320,'phone'),(390,'phone'),(768,'tablet'),(1440,'desktop')]:
                    page.set_viewport_size({'width':width,'height':1000})
                    page.locator('button[data-size='+size+']').click()
                    for large in [False,True]:
                        page.locator('#large-text').set_checked(large)
                        page.wait_for_timeout(15)
                        check(page.locator('#app').evaluate('e=>e.scrollWidth<=e.clientWidth+1'),f'frame horizontal overflow {concept} {width} {large}')
                        check(page.locator('.scroll').evaluate('e=>e.scrollWidth<=e.clientWidth+1'),f'content overflow {concept} {width} {large}')
                        check(page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'),f'page overflow {concept} {width}')
                page.set_viewport_size({'width':1440,'height':1200});page.locator('button[data-size=phone]').click();page.locator('#large-text').uncheck()
                if args.screenshots:
                    page.wait_for_timeout(50)
                    args.screenshots.mkdir(parents=True,exist_ok=True)
                    if concept=='A':click('menu')
                    page.screenshot(path=str(args.screenshots/(concept+'-phone.png')),full_page=True)
                    if concept=='A':click('close-modal')
                    page.locator('button[data-size=desktop]').click();page.wait_for_timeout(25)
                    page.locator('#app').screenshot(path=str(args.screenshots/(concept+'-desktop.png')))
            page.locator('button[data-size=phone]').click();page.locator('#large-text').check();page.locator('#keyboard').check();page.locator('#light-theme').check()
            click('search');check(page.locator('#field-query').is_visible(),'search field visible in keyboard/text stress mode')
            check(page.locator('#modal').evaluate('e=>e.scrollWidth<=e.clientWidth+1'),'modal no horizontal overflow')
            click('close-modal')
        test('24 responsive concept/size/text combinations plus keyboard/light stress',layouts)
        check(not requests,'Unexpected network requests: '+str(requests))
        check(not errors,'Unexpected browser errors: '+str(errors))
        print(json.dumps({'journeys':len(completed),'layout_combinations':24 if args.group in ('all','layout') else 0,'page_errors':errors,'network_requests':requests},indent=2))
        page.close()
        browser.close()

if __name__=='__main__':
    main()
