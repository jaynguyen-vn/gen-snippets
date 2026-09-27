export type Snippet = {
  command: string;
  description: string;
  content: string;
};

export const SIGNATURE =
  "Best regards,\nAlex Morgan\nProduct Designer · Northwind Studio\nalex@example.com · +1 (555) 010-2030";

export const WELCOME_TEMPLATE = "Hi {{name}}, welcome to {{company}}! Your account is ready.";

// Sample library shown in the Quick Search panel. Everything the video types
// elsewhere comes from here, so the story stays consistent.
export const SNIPPETS: Snippet[] = [
  { command: ";sig", description: "Email signature", content: SIGNATURE },
  { command: ";welcome", description: "Welcome message", content: WELCOME_TEMPLATE },
  { command: ";log", description: "Timestamped log line", content: 'console.log("[{time}] {cursor}");' },
  { command: ";date", description: "Today's date", content: "{dd/mm/yyyy}" },
  { command: ";link", description: "Share a copied link", content: "Sure: {clipboard}" },
  { command: ";qr", description: "QR code to the download page", content: "[Image] qr-code.png" },
  { command: ";addr", description: "Home address", content: "Alex Morgan\n123 Main Street, Apt 4B\nSpringfield, IL 62704" },
  {
    command: ";addr-work",
    description: "Office address",
    content: "Northwind Studio\n500 Market Street, Floor 3\nSpringfield, IL 62701",
  },
  { command: ";guide", description: "Quick-start guide (PDF)", content: "[File] Quick-Start-Guide.pdf" },
];

/** Same rule as ModernSnippetSearchView: command, description or content contains the query. */
export const searchSnippets = (query: string) => {
  const q = query.toLowerCase();
  if (q === "") {
    return SNIPPETS;
  }
  return SNIPPETS.filter(
    (s) =>
      s.command.toLowerCase().includes(q) ||
      s.description.toLowerCase().includes(q) ||
      s.content.toLowerCase().includes(q),
  );
};
