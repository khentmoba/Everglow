'use strict';

// Server-side calendar reads use Philippine wall time, like reminders.
const PHT_OFFSET = 8 * 60 * 60 * 1000;
function calendarDatesBetween(date, recurring, start, end) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime()) || end <= start) return [];
  if (!['monthly', 'yearly'].includes(recurring)) return date >= start && date < end ? [date] : [];
  const anchor = new Date(date.getTime() + PHT_OFFSET);
  const from = new Date(start.getTime() + PHT_OFFSET);
  let year = Math.max(anchor.getUTCFullYear(), from.getUTCFullYear());
  let month = recurring === 'yearly' || start < date ? anchor.getUTCMonth() : from.getUTCMonth();
  const dates = [];
  while (Date.UTC(year, month, 1) - PHT_OFFSET < end.getTime()) {
    const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    const occurrence = new Date(Date.UTC(year, month, Math.min(anchor.getUTCDate(), lastDay),
      anchor.getUTCHours(), anchor.getUTCMinutes(), anchor.getUTCSeconds(), anchor.getUTCMilliseconds()) - PHT_OFFSET);
    if (occurrence >= date && occurrence >= start && occurrence < end) dates.push(occurrence);
    if (recurring === 'yearly') year++;
    else if (month === 11) { month = 0; year++; }
    else month++;
  }
  return dates;
}

async function getCalendarEvents(db, Timestamp, start, end, limit) {
  const day = new Date(start.getTime() + PHT_OFFSET).toISOString().slice(0, 10);
  const queryStart = new Date(`${day}T00:00:00+08:00`);
  // ponytail: 100 source entries per query; paginate if the shared calendar outgrows this.
  const [dated, recurring] = await Promise.all([
    db.collection('calendar_events').where('date', '>=', Timestamp.fromDate(queryStart))
      .where('date', '<', Timestamp.fromDate(end)).orderBy('date', 'asc').limit(100).get(),
    db.collection('calendar_events').where('recurring', 'in', ['monthly', 'yearly']).limit(100).get(),
  ]);
  const docs = new Map([...dated.docs, ...recurring.docs].map((doc) => [doc.id, doc.data()]));
  const events = [];
  for (const [id, data] of docs) {
    const original = data.date?.toDate?.();
    for (const date of calendarDatesBetween(original, data.recurring, queryStart, end)) {
      if (data.isAllDay || date >= start) events.push({ ...data, id, date });
    }
  }
  return events.sort((a, b) => a.date - b.date).slice(0, limit);
}

module.exports = { calendarDatesBetween, getCalendarEvents };
