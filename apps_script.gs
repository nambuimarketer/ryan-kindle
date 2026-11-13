/**
 * Google Apps Script: trả về lịch Google (hôm nay + ngày mai) dạng JSON, kèm việc cần làm (từ vault Obsidian)
 * và mức dùng Claude do Mac gửi lên.
 * Chạy dưới tài khoản Google của bạn — không cần Google Cloud Console.
 *
 * Cài đặt (xem README, mục 1):
 *  1. script.google.com → New project → dán toàn bộ file này.
 *  2. Đổi TOKEN bên dưới thành một chuỗi bí mật bất kỳ.
 *  3. (Không cần thêm Google Tasks API: việc cần làm lấy từ vault.)
 *  4. Deploy → New deployment → Web app; Execute as: Me; Who has access: Anyone → Deploy, cho phép quyền.
 *  5. Copy "Web app URL" → GitHub secret DATA_URL = <URL>?token=<TOKEN>
 */
const TOKEN = 'DOI-THANH-CHUOI-BI-MAT';
const TZ = 'Asia/Ho_Chi_Minh';

function doGet(e) {
  if (!e || !e.parameter || e.parameter.token !== TOKEN) {
    return ContentService.createTextOutput('{"error":"forbidden"}').setMimeType(ContentService.MimeType.JSON);
  }
  return ContentService.createTextOutput(JSON.stringify(collect_())).setMimeType(ContentService.MimeType.JSON);
}

/** Mac gửi lên đây (POST ?token=...): mức dùng Claude, hoặc việc trong vault khi có &kind=vault. */
function doPost(e) {
  if (!e || !e.parameter || e.parameter.token !== TOKEN) {
    return ContentService.createTextOutput('{"error":"forbidden"}').setMimeType(ContentService.MimeType.JSON);
  }
  const body = JSON.parse(e.postData.contents);
  if (e.parameter.kind === 'vault') {
    // Việc cần làm từ vault: {tasks:[{title,due,time,list}], total, dated}
    const v = { fetched_at: new Date().toISOString(), tasks: (body.tasks || []).slice(0, 30), total: body.total || 0, dated: body.dated || 0 };
    let txt = JSON.stringify(v);
    while (txt.length > 8500 && v.tasks.length > 5) {   // mỗi mục lưu trữ tối đa khoảng 9 KB
      v.tasks.pop();
      txt = JSON.stringify(v);
    }
    PropertiesService.getScriptProperties().setProperty('vault_tasks', txt);
    return ContentService.createTextOutput('{"ok":true}').setMimeType(ContentService.MimeType.JSON);
  }
  // Giữ mọi mục có % sử dụng (five_hour, seven_day, Fable, ...) + danh sách tên mục để dò lỗi
  const keep = { fetched_at: new Date().toISOString(), bucket_keys: Object.keys(body) };
  Object.keys(body).forEach(function (k) {
    const v = body[k];
    if (v && typeof v === 'object' && typeof v.utilization === 'number') {
      keep[k] = { utilization: v.utilization, resets_at: v.resets_at || null };
    }
  });
  // Bản thô (chỉ các mục khác null): Fable nằm trong danh sách "limits" ở đây
  const raw = {};
  Object.keys(body).forEach(function (k) { if (body[k] !== null) raw[k] = body[k]; });
  keep.raw = JSON.stringify(raw).slice(0, 6000);
  PropertiesService.getScriptProperties().setProperty('claude_usage', JSON.stringify(keep));
  return ContentService.createTextOutput('{"ok":true}').setMimeType(ContentService.MimeType.JSON);
}

function collect_() {
  const today = Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd');
  const start = new Date(today + 'T00:00:00+07:00');
  const end = new Date(start.getTime() + 2 * 86400000);

  const events = [];
  CalendarApp.getAllCalendars().forEach(function (cal) {
    if (cal.isHidden() || !cal.isSelected()) return;
    cal.getEvents(start, end).forEach(function (ev) {
      try {
        if (ev.getMyStatus() === CalendarApp.GuestStatus.NO) return;  // đã từ chối
      } catch (err) {}
      const o = { title: ev.getTitle() || '(Không tiêu đề)', location: ev.getLocation() || '', calendar: cal.getName() };
      if (ev.isAllDayEvent()) {
        o.allDay = true;
        o.startDate = Utilities.formatDate(ev.getAllDayStartDate(), TZ, 'yyyy-MM-dd');
        o.endDate = Utilities.formatDate(ev.getAllDayEndDate(), TZ, 'yyyy-MM-dd');
      } else {
        o.allDay = false;
        o.start = ev.getStartTime().toISOString();
        o.end = ev.getEndTime().toISOString();
      }
      events.push(o);
    });
  });

  // Việc cần làm: do Mac đọc từ vault Obsidian rồi gửi lên (doPost, kind=vault)
  const vaultRaw = PropertiesService.getScriptProperties().getProperty('vault_tasks');
  const vault = vaultRaw ? JSON.parse(vaultRaw) : null;
  const tasks = vault ? vault.tasks || [] : [];
  const vaultMeta = vault ? { fetched_at: vault.fetched_at, total: vault.total, dated: vault.dated } : null;

  const claudeRaw = PropertiesService.getScriptProperties().getProperty('claude_usage');
  return { generated: new Date().toISOString(), events: events, tasks: tasks, vault: vaultMeta, claude: claudeRaw ? JSON.parse(claudeRaw) : null };
}

/** Bấm Run hàm này trong trình soạn thảo để kiểm tra (xem kết quả ở Execution log). */
function testCollect() {
  Logger.log(JSON.stringify(collect_(), null, 2));
}
