export async function fetchAllMessagePages(fetchPage, pageSize = 300) {
  const messages = [];

  for (let offset = 0; ; offset += pageSize) {
    const page = await fetchPage(offset, pageSize);
    messages.push(...page);
    if (page.length < pageSize) return messages;
  }
}
