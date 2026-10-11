/**
 * NG-like presentation of the forum's OWN login form. Inputs, hidden tokens,
 * password hashing, AJAX submission and error targets remain owned by 4D4Y.
 * No credential is read, returned to ArkTS, logged or stored by this script.
 * Unknown forms / security challenges retain the visible website fallback.
 */
export function buildFourD4yLoginPresentationScript(): string {
  return `(() => {
    if (location.origin !== 'https://www.4d4y.com' ||
        location.pathname !== '/forum/logging.php' ||
        new URL(location.href).searchParams.get('action') !== 'login') return 'website';
    const form = document.querySelector('form#loginform');
    if (!form || (form.getAttribute('method') || '').toLowerCase() !== 'post') return 'website';
    const target = new URL(form.getAttribute('action') || '', location.href);
    if (target.origin !== location.origin || target.pathname !== '/forum/logging.php' ||
        target.searchParams.get('action') !== 'login' ||
        target.searchParams.get('loginsubmit') !== 'yes') return 'website';
    if (document.querySelector('#challenge-form, [id^="cf-chl"], .g-recaptcha, .h-captcha') ||
        form.querySelector('input[name="seccodeverify"], input[name="secanswer"], iframe')) return 'website';
    const username = form.querySelector('input[name="username"][type="text"]');
    const password = form.querySelector('input[name="password"][type="password"]#password3');
    const question = form.querySelector('select[name="questionid"]#questionid');
    const answer = form.querySelector('input[name="answer"][type="text"]#answer');
    const submit = form.querySelector('button[name="loginsubmit"][type="submit"]');
    const loginfield = form.querySelector('select[name="loginfield"]');
    const remember = form.querySelector('input[name="cookietime"][type="checkbox"]');
    if (!username || !password || !question || !answer || !submit || !loginfield || !remember ||
        !form.querySelector('input[name="formhash"][type="hidden"]')) return 'website';
    if (document.getElementById('oh-login-style')) return 'compact';

    // Discuz simulateSelect collapses the real select to one option. Restore
    // its PUBLIC choices from the site's generated menu, not guessed values.
    const menu = document.getElementById('questionid_ctrl_menu');
    const choices = menu ? Array.from(menu.querySelectorAll('li')).map(item => ({
      value: String(item.k_value), label: (item.textContent || '').trim()
    })) : Array.from(question.options).map(item => ({ value: item.value, label: item.textContent.trim() }));
    if (choices.length !== 8 || choices.some((item, index) => item.value !== String(index) || !item.label)) {
      return 'website';
    }
    const selectedQuestion = question.value;
    question.replaceChildren();
    choices.forEach(item => {
      const option = document.createElement('option');
      option.value = item.value;
      option.textContent = item.value === '0' ? '无安全提问' : item.label;
      question.appendChild(option);
    });
    question.value = selectedQuestion;
    loginfield.value = 'username';
    remember.checked = true; // NG's persistent login; never remembers a password.
    username.placeholder = '用户名';
    password.placeholder = '密码';
    answer.placeholder = '回答';
    username.setAttribute('aria-label', '用户名');
    password.setAttribute('aria-label', '密码');
    question.setAttribute('aria-label', '安全提问');
    answer.setAttribute('aria-label', '回答');
    let node = form;
    while (node && node !== document.body) {
      node.setAttribute('data-oh-login-path', '1');
      node = node.parentElement;
    }
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      document.head.appendChild(viewport);
    }
    viewport.content = 'width=device-width, initial-scale=1';
    const message = document.getElementById('returnmessage');
    if (message && (message.textContent || '').trim() === '用户登录') message.textContent = '';
    const style = document.createElement('style');
    style.id = 'oh-login-style';
    style.textContent = \`
      html, body { margin:0!important; min-width:0!important; width:100%!important;
        background:#fff!important; color:#222!important; font-family:sans-serif!important; }
      body { box-sizing:border-box; padding:20px 24px!important; }
      body > :not([data-oh-login-path]):not(#append_parent):not(#ajaxwaitid) { display:none!important; }
      #ajaxwaitid { position:fixed!important; top:auto!important; bottom:8px!important;
        left:0!important; right:0!important; width:100%!important; box-sizing:border-box;
        font-size:13px!important; text-align:center; }
      [data-oh-login-path] { float:none!important; min-width:0!important; width:100%!important;
        box-sizing:border-box; margin:0!important; padding:0!important; border:0!important;
        background:transparent!important; }
      #layer_login h3 { margin:0!important; padding:0!important; height:auto!important;
        min-height:0!important; font-size:13px!important; line-height:20px!important;
        border:0!important; background:transparent!important; }
      #layer_login h3 > :not(#returnmessage), #loginform .logininfo,
      #loginfield, #loginfield_ctrl, #questionid_ctrl, #questionid_ctrl_menu,
      #loginform label, #loginform .fsubmit input { display:none!important; }
      #returnmessage { display:block!important; color:#b42318; white-space:normal!important; }
      #returnmessage:empty { display:none!important; }
      #loginform .loginform, #loginform .loginform > *, #loginform .fsubmit {
        float:none!important; width:100%!important; height:auto!important;
        min-width:0!important; box-sizing:border-box; padding:0!important; margin:0!important;
        border:0!important; background:transparent!important; }
      #loginform input[name=username], #password3, #answer {
        display:block!important; box-sizing:border-box; width:100%!important; height:48px!important;
        font-size:18px!important; line-height:normal!important; color:#222!important;
        background:transparent!important; border:0!important; border-bottom:1px dashed #aaa!important;
        border-radius:0!important; padding:8px!important; margin:0 0 12px!important; outline:none; }
      #loginform input::placeholder { color:#999; }
      #questionid { display:block!important; box-sizing:border-box; width:100%!important;
        height:56px!important; font-size:18px!important; color:#222!important; background:#fff!important;
        border:0!important; padding:8px 4px!important; margin:4px 0 12px!important; }
      #loginform button[name=loginsubmit] { float:none!important; display:block!important;
        width:100%!important; height:48px!important; margin:12px 0 0!important; padding:0!important;
        border:0!important; border-radius:0!important; background:transparent!important;
        color:#222!important; font-size:18px!important; box-shadow:none!important; }
      #seccodelayer { max-width:100%; }
      #seccodelayer img { max-width:100%; height:auto; }
      #layer_message { width:100%!important; min-width:0!important; }
    \`;
    document.head.appendChild(style);
    return 'compact';
  })()`;
}
