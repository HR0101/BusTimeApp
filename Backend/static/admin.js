const $ = (id) => document.getElementById(id);
let stops = [],
  snapshot = null,
  pending = null;
function message(text, error = false) {
  $("status").textContent = text;
  $("status").setAttribute("role", error ? "alert" : "status");
}
async function request(path, options = {}, auth = true) {
  const response = await fetch("/api/v1/" + path, {
    ...options,
    headers: {
      ...(auth ? { "X-Admin-Key": $("key").value } : {}),
      ...options.headers,
    },
  });
  if (!response.ok) {
    const body = await response
      .json()
      .catch(() => ({ detail: response.statusText }));
    throw Error(
      typeof body.detail === "string"
        ? body.detail
        : JSON.stringify(body.detail),
    );
  }
  return response;
}
const json = (path, body) =>
  request(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }).then((r) => r.json());
function option(select, value, text) {
  const el = document.createElement("option");
  el.value = value;
  el.textContent = text;
  select.append(el);
}
function button(parent, text, action) {
  const el = document.createElement("button");
  el.textContent = text;
  el.onclick = () => run(action);
  parent.append(el);
}
async function run(action) {
  try {
    message("処理中…");
    await action();
    message("完了しました。");
  } catch (e) {
    message(e.message, true);
  }
}
async function load() {
  snapshot = await (
    await request("timetables/" + $("route").value, {}, false)
  ).json();
  $("trips").replaceChildren();
  for (const trip of snapshot.buses.sort(
    (a, b) => serviceMinutes(a.departure) - serviceMinutes(b.departure),
  )) {
    const row = document.createElement("tr");
    for (const text of [
      trip.schedule_id,
      trip.departure + " → " + trip.arrival,
      trip.note || "",
    ]) {
      const td = document.createElement("td");
      td.textContent = text;
      row.append(td);
    }
    const actions = document.createElement("td");
    button(actions, "編集", () => edit(trip));
    button(actions, "削除を確認", () =>
      preview({ changes: [{ operation: "delete", id: trip.id }] }),
    );
    row.append(actions);
    $("trips").append(row);
  }
  for (const id of ["schedule", "scheduleEdit"]) {
    $(id).replaceChildren();
    if (id === "scheduleEdit") option($(id), "", "新しいダイヤ");
    for (const s of snapshot.schedules)
      option($(id), s.id, s.id + (s.is_suspended ? "（運休）" : ""));
  }
  newTrip();
  editSchedule();
}
function stopRow(stop = { stop_id: stops[0]?.id, time: "9:00" }) {
  const row = document.createElement("div");
  row.className = "stop";
  const select = document.createElement("select");
  for (const s of stops) option(select, s.id, s.name);
  select.value = stop.stop_id;
  const time = document.createElement("input");
  time.type = "time";
  time.value = stop.time.padStart(5, "0");
  row.append(select, time);
  button(row, "除く", () => row.remove());
  $("stops").append(row);
}
function edit(trip) {
  $("tripid").value = trip.id;
  $("tripid").readOnly = true;
  $("schedule").value = trip.schedule_id;
  $("note").value = trip.note || "";
  $("stops").replaceChildren();
  trip.stops.forEach(stopRow);
}
function serviceMinutes(time) {
  const [hour, minute] = time.split(":").map(Number);
  return (hour + (hour < 4 ? 24 : 0)) * 60 + minute;
}
function newTrip() {
  $("tripid").value = "";
  $("tripid").readOnly = false;
  $("note").value = "";
  $("schedule").value =
    snapshot?.schedules.find((s) => s.kind === "weekday" && !s.is_suspended)
      ?.id ||
    snapshot?.schedules[0]?.id ||
    "";
  $("stops").replaceChildren();
  const route = snapshot?.route_id.split("-");
  if (route) {
    stopRow({ stop_id: route[0], time: "9:00" });
    stopRow({ stop_id: route[1], time: "9:20" });
  }
}
function describe(trip) {
  return trip
    ? trip.stops.map((s) => s.name + " " + s.time).join(" → ") +
        (trip.note ? " / " + trip.note : "")
    : "便なし";
}
function showDiff(result) {
  $("diff").replaceChildren();
  for (const change of result.changes) {
    const p = document.createElement("p");
    p.textContent =
      change.id +
      "\n変更前: " +
      describe(change.before) +
      "\n変更後: " +
      describe(change.after);
    p.className = "diff-line";
    $("diff").append(p);
  }
  $("confirmation").hidden = false;
  $("confirmation").scrollIntoView({ behavior: "smooth" });
}
async function preview(batch) {
  const result = await json("admin/preview", batch);
  pending = { batch };
  showDiff(result);
}
function editSchedule() {
  const s = snapshot?.schedules.find((s) => s.id === $("scheduleEdit").value);
  $("scheduleid").value = s?.id || "";
  $("kind").value = s?.kind || "special";
  $("serviceDate").value = s?.service_date || "";
  $("validFrom").value = s?.valid_from || "";
  $("validUntil").value = s?.valid_until || "";
  $("priority").value = s?.priority || 0;
  $("suspended").checked = s?.is_suspended || false;
}
$("connect").onclick = () =>
  run(async () => {
    const routes = await (await request("routes", {}, false)).json();
    stops = (await (await request("stops", {}, false)).json()).stops;
    $("route").replaceChildren();
    routes.routes.forEach((r) => option($("route"), r.id, r.name));
    await load();
    await publications();
  });
$("route").onchange = () => run(load);
$("new").onclick = newTrip;
$("addstop").onclick = () => stopRow();
$("scheduleEdit").onchange = editSchedule;
$("preview").onclick = () =>
  run(() =>
    preview({
      changes: [
        {
          operation: "upsert",
          trip: {
            id: $("tripid").value,
            route_id: $("route").value,
            schedule_id: $("schedule").value,
            stops: [...$("stops").children].map((row) => ({
              stop_id: row.querySelector("select").value,
              time: row.querySelector("input").value,
            })),
            note: $("note").value || null,
          },
        },
      ],
    }),
  );
$("saveSchedule").onclick = () =>
  run(async () => {
    const value = {
      id: $("scheduleid").value,
      route_id: $("route").value,
      kind: $("kind").value,
      service_date: $("serviceDate").value || null,
      valid_from: $("validFrom").value || null,
      valid_until: $("validUntil").value || null,
      priority: Number($("priority").value),
      is_suspended: $("suspended").checked,
    };
    if (!confirm("この運行日設定をすぐに公開しますか？")) return;
    await request("schedules/" + encodeURIComponent(value.id), {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(value),
    });
    await load();
  });
$("export").onclick = () =>
  run(async () => {
    const blob = await (await request("admin/export.csv")).blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "timetables.csv";
    a.click();
    URL.revokeObjectURL(url);
  });
$("import").onclick = () =>
  run(async () => {
    const file = $("csv").files[0];
    if (!file) throw Error("CSVファイルを選んでください。");
    const content = await file.text();
    const result = await (
      await request("admin/import.csv?preview=true", {
        method: "POST",
        headers: { "Content-Type": "text/csv" },
        body: content,
      })
    ).json();
    pending = {
      batch: {
        changes: result.changes.map((c) => ({
          operation: "upsert",
          trip: {
            id: c.after.id,
            route_id: c.after.route_id,
            schedule_id: c.after.schedule_id,
            stops: c.after.stops.map((s) => ({
              stop_id: s.stop_id,
              time: s.time,
            })),
            note: c.after.note,
          },
        })),
      },
    };
    showDiff(result);
  });
$("cancel").onclick = () => {
  pending = null;
  $("confirmation").hidden = true;
};
$("commit").onclick = () =>
  run(async () => {
    if (!pending) throw Error("変更をもう一度確認してください。");
    $("commit").disabled = true;
    try {
      let batch = pending.batch;
      if ($("publishAt").value) {
        await json("admin/publications", {
          ...batch,
          publish_at: new Date($("publishAt").value).toISOString(),
        });
      } else await json("admin/batch", batch);
      pending = null;
      $("confirmation").hidden = true;
      await load();
      await publications();
    } finally {
      $("commit").disabled = false;
    }
  });
async function publications() {
  const result = await (await request("admin/publications")).json();
  $("publicationList").replaceChildren();
  for (const p of result.publications) {
    const line = document.createElement("p");
    line.textContent =
      new Date(p.publish_at).toLocaleString() +
      " / " +
      ({ pending: "公開待ち", published: "公開済み", failed: "失敗" }[
        p.status
      ] || p.status) +
      (p.error ? " / " + p.error : "");
    $("publicationList").append(line);
  }
}
$("publications").onclick = () => run(publications);
