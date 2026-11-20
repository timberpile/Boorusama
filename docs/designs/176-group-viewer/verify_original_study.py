"""Prototype-only browser checks. Requires Python Playwright and Chromium.
Run: python verify_original_study.py --chromium /usr/bin/chromium
No Flutter, network, Android or real profile operations are performed.
"""
from __future__ import annotations
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--chromium', default='/usr/bin/chromium')
parser.add_argument('--evidence', type=Path, default=Path('prototype-evidence'))
args = parser.parse_args()
html_path = Path(__file__).with_name('original-study.html')
html = html_path.read_text(encoding='utf-8')
args.evidence.mkdir(parents=True, exist_ok=True)
script = re.search(r'<script>(.*?)</script>', html, re.S)
assert script, 'Inline script missing'
with tempfile.NamedTemporaryFile(mode='w', suffix='.js') as f:
    f.write(script.group(1)); f.flush()
    subprocess.run(['node', '--check', f.name], check=True)
checks: list[str] = []
errors: list[str] = []

def check(condition: bool, description: str) -> None:
    if not condition:
        raise AssertionError(description)
    checks.append(description)

with sync_playwright() as pw:
    browser = pw.chromium.launch(executable_path=args.chromium, args=['--no-sandbox'])
    page = browser.new_page(viewport={'width': 1440, 'height': 1100}, device_scale_factor=1)
    page.set_default_timeout(5000)
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.set_content(html, wait_until='load')
    snapshot = lambda: page.evaluate('studySnapshot()')
    click = lambda action: page.locator(f'[data-action="{action}"]').first.click()
    def fresh() -> None:
        page.goto('about:blank')
        page.set_content(html, wait_until='load')
    def close() -> None:
        page.locator('#dialog [data-action="close"]').first.click()
        page.wait_for_timeout(30)
    def switch(mode: str, variant: str) -> None:
        if variant == 'B':
            click('view')
            page.locator(f'[data-mode="{mode}"]').click()
        else:
            click(mode)
        page.wait_for_timeout(120)
    def jump(member: str) -> None:
        click('jump')
        page.locator(f'[data-action="jump-member"][data-id="{member}"]').click()
        page.wait_for_timeout(30)
    def assert_layout(label: str) -> None:
        geometry = page.evaluate('''() => {
          const phone=document.querySelector('#phone'), app=document.querySelector('#app');
          const content=document.querySelector('.content');
          const mode=document.querySelector('.seg');
          return {body:document.documentElement.scrollWidth<=innerWidth+1,
            phone:phone.scrollWidth<=phone.clientWidth+1,
            app:app.scrollWidth<=app.clientWidth+1,
            media:content.clientHeight>80,
            mode:!mode||mode.scrollWidth<=mode.clientWidth+1};
        }''')
        check(all(geometry.values()), f'{label}: no horizontal overflow; content remains usable {geometry}')

    check(snapshot()['selected']=='m3', 'Demo starts at member 3')
    for variant in ('A','B','C'):
        page.locator(f'[data-variant="{variant}"]').click()
        jump('m4')
        switch('timeline',variant)
        check(snapshot()['selected']=='m4', f'{variant}: fourth member survives programmatic timeline reveal')
        page.locator('.content').evaluate('(el)=>el.scrollTop=el.scrollHeight')
        page.wait_for_timeout(150)
        check(snapshot()['selected']=='m4', f'{variant}: passive scrolling does not change selection')
        switch('single',variant)
        check(snapshot()['selected']=='m4', f'{variant}: return to Single retains identity')
        click('order')
        check(page.locator('#dialog input[value="custom"]').count()==1, f'{variant}: order editor reachable in Single')
        close()
        switch('timeline',variant)
        click('order')
        check(page.locator('#dialog input[value="custom"]').count()==1, f'{variant}: order editor reachable in Timeline')
        close(); switch('single',variant)
    page.locator('[data-variant="A"]').click()
    click('order'); page.locator('input[value="custom"]').check()
    page.locator('[data-action="move-up"][data-id="m4"]').click()
    close()
    check(snapshot()['sequence']==['m1','m2','m3','m4','m5','m6'], 'Cancel discards draft order')
    click('order'); page.locator('input[value="custom"]').check()
    page.locator('[data-action="move-up"][data-id="m4"]').click(); click('save-order')
    check(snapshot()['sequence']==['m1','m2','m4','m3','m5','m6'], 'Save applies custom order')
    check(snapshot()['selected']=='m4', 'Reordering preserves selected member identity')
    click('timeline'); page.wait_for_timeout(120)
    check(page.locator('.tile').evaluate_all('(els)=>els.map(e=>e.dataset.id)')==snapshot()['sequence'], 'Timeline uses saved Single sequence')
    click('undo')
    check(snapshot()['sequence']==['m1','m2','m3','m4','m5','m6'], 'Undo restores prior order')
    page.locator('.content').evaluate('(el)=>el.scrollTop=150')
    page.wait_for_timeout(50)
    saved_scroll=page.locator('.content').evaluate('(el)=>el.scrollTop')
    click('single');click('timeline')
    check(abs(page.locator('.content').evaluate('(el)=>el.scrollTop')-saved_scroll)<1, 'Mode round-trip preserves passive timeline scroll offset')
    click('back'); check(snapshot()['origin'], 'Back returns directly to origin after mode switches')
    click('reopen'); check(snapshot()['mode']=='timeline' and snapshot()['selected']=='m4', 'Reopen restores mode and member')
    click('outer-next'); check(snapshot()['outer']==9 and snapshot()['selected']=='m1', 'Next feed occurrence has its own position')
    check(snapshot()['mode']=='timeline', 'New occurrence honors last mode for this group type')
    click('outer-prev'); check(snapshot()['selected']=='m4', 'Returning feed occurrence restores previous identity')
    click('single'); jump('m6')
    check(page.locator('[data-action="next"]').is_disabled(), 'Last member disables inner Next instead of leaving group')
    jump('m1'); check(page.locator('[data-action="prev"]').is_disabled(), 'First member disables inner Previous')

    for kind in ('series','pixiv'):
        page.locator('#kind').select_option(kind)
        click('order')
        check(page.locator('#dialog input[name="ordering"]').count()==0, f'{kind}: source order cannot be edited')
        close(); click('timeline'); click('order')
        check(page.locator('#dialog input[name="ordering"]').count()==0, f'{kind}: Timeline retains source order restriction')
        close(); click('single')
    page.locator('#kind').select_option('pool'); click('order')
    check(page.locator('#dialog input[name="ordering"]').count()==3, 'Pool offers Ordered, Oldest and Newest')
    close()
    page.locator('#kind').select_option('related'); click('single')
    page.locator('#condition').select_option('missing'); jump('m4')
    check(page.locator('.media .art').count()==0, 'Unavailable member has no media preview')
    check('4 / 6' in page.locator('.counter').inner_text(), 'Unavailable member retains position 4 of 6')
    click('timeline'); check(page.locator('.tile').count()==6, 'Timeline keeps unavailable occurrence in sequence')
    page.locator('#condition').select_option('restricted')
    check(page.locator('.tile[data-id="m4"] .art').count()==0, 'Restricted timeline slot leaks no preview')
    click('single'); click('info')
    check('Restricted' in page.locator('#dialog').inner_text(), 'Details report source restriction')
    close(); click('back')
    check(page.locator('.origin-card .art').count()==0, 'Origin preview does not expose restricted selected image')
    click('reopen')
    page.locator('#condition').select_option('partial'); click('order')
    check(page.locator('input[value="custom"]').is_disabled(), 'Partial manifest blocks starting custom order')
    close(); jump('m3'); click('next')
    check(len(snapshot()['sequence'])==6 and snapshot()['selected']=='m4', 'Inner next loads continuation without advancing outer item')
    for condition in ('loading','offline'):
        selected=snapshot()['selected']
        page.locator('#condition').select_option(condition)
        click('resolve')
        check(snapshot()['selected']==selected, f'{condition}: recovery retains position')
    click('info'); check(page.locator('#dialog').evaluate('(d)=>d.contains(document.activeElement)'), 'Dialog receives focus')
    page.keyboard.press('Escape'); page.wait_for_timeout(30)
    check(not page.locator('#dialog').evaluate('(d)=>d.open'), 'Escape dismisses modal')
    check(page.locator('[data-action="info"]').evaluate('(e)=>e===document.activeElement'), 'Modal returns focus to trigger')
    page.locator('.content').focus(); page.keyboard.press('ArrowLeft'); first=snapshot()['selected'];page.keyboard.press('ArrowLeft')
    check(first!=snapshot()['selected'], 'Repeated keyboard navigation survives rerender')
    click('chrome');check(page.locator('#phone').evaluate('(e)=>e.classList.contains("immersive")'), 'Media tap hides chrome')
    click('chrome');check(page.locator('[data-action="info"]').is_visible(), 'Media tap restores chrome')
    click('chrome');page.keyboard.press('Escape')
    check(snapshot()['origin'], 'Back from hidden chrome exits directly, without extra history')
    click('reopen')
    click('order');page.locator('input[value="custom"]').check();click('save-order')
    page.locator('#condition').select_option('partial');click('order')
    check(page.locator('.order-item').count()==0 and page.locator('[data-action="save-order"]').is_disabled(), 'Existing Custom order is not editable with a partial manifest')
    close();page.locator('#condition').select_option('normal')
    for variant in ('A','B','C'):
        page.locator(f'[data-variant="{variant}"]').click()
        for theme in ('dark','light','amoled'):
            page.locator('#theme').select_option(theme)
            for width in ('phone','narrow','wide'):
                page.locator('#viewport').select_option(width)
                assert_layout(f'{variant}/{theme}/{width}')
    page.locator('#viewport').select_option('narrow')
    page.locator('#largeText').check()
    for variant in ('A','B','C'):
        page.locator(f'[data-variant="{variant}"]').click()
        assert_layout(f'{variant}/320/200% text')
    page.locator('#largeText').uncheck()
    page.locator('#viewport').select_option('phone')
    for variant in ('A','B','C'):
        fresh();page.locator(f'[data-variant="{variant}"]').click()
        page.locator('#phone').screenshot(path=str(args.evidence/f'{variant.lower()}-single.png'))
        switch('timeline',variant)
        page.locator('#phone').screenshot(path=str(args.evidence/f'{variant.lower()}-timeline.png'))
    fresh();page.screenshot(path=str(args.evidence/'workspace.png'), full_page=True)
    click('order');page.locator('input[value="custom"]').check()
    page.screenshot(path=str(args.evidence/'custom-order.png'), full_page=True)
    close()
    for width in (320,390,768,1280):
        page.set_viewport_size({'width':width,'height':900})
        assert_layout(f'browser {width}px')
    page.set_viewport_size({'width':1440,'height':1100})
    check(not errors, 'No browser runtime errors across checked interactions')
    version=browser.version
    browser.close()
result={'checks_passed':len(checks),'browser':version,'checks':checks,'runtime_errors':errors}
(args.evidence/'results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'checks_passed':len(checks),'browser':version,'runtime_errors':errors}))
