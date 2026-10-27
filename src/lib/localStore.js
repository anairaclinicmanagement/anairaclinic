const PREFIX = "anaira-clinic-v1:";
const read = (key, fallback = []) => {
  try {
    const value = JSON.parse(localStorage.getItem(PREFIX + key) || "null");
    return value ?? fallback;
  } catch { return fallback; }
};
const write = (key, value) => localStorage.setItem(PREFIX + key, JSON.stringify(value));

export const localStore = {
  get: (key, fallback) => read(key, fallback),
  set: (key, value) => write(key, value),
  add(key, item) {
    const items = read(key, []);
    items.unshift(item);
    write(key, items);
    const queue = read("sync-queue", []);
    queue.unshift({ id: crypto.randomUUID?.() || String(Date.now()), table: key, operation: "insert", payload: item, status: "pending", createdAt: new Date().toISOString() });
    write("sync-queue", queue);
    return item;
  },
  remove(key, id) {
    write(key, read(key, []).filter(item => item.id !== id));
  }
};
