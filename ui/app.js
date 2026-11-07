"use strict";

const PASS = "PASS";
const FAIL = "FAIL";
const ETHERSCAN = "https://sepolia.etherscan.io/address/";

const explorerNames = {
  1: "etherscan.io",
  31337: null,
  11155111: "sepolia.etherscan.io",
};

function shortAddress(address) {
  if (typeof address !== "string" || address.length < 12) return address || "—";
  return address.slice(0, 6) + "…" + address.slice(-4);
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function render(report) {
  renderBanner(report);
  renderInvariants(report);
  renderRecords(report);
  renderFooter(report);
}

function renderBanner(report) {
  const banner = document.getElementById("status-banner");
  const failed = report.invariants.filter((i) => i.status === FAIL).length;
  const passed = report.invariants.length - failed;
  banner.className = "status-banner " + (failed ? "fail" : "pass");
  const text = document.getElementById("banner-text");
  text.textContent = "";
  text.appendChild(el("span", null, failed ? "FAIL" : "PASS"));
  text.appendChild(
    el("small", null, `${passed} of ${report.invariants.length} invariants passed`),
  );
  const netBadge = document.getElementById("network-badge");
  const explorer = explorerNames[report.network];
  netBadge.textContent = explorer ? explorer : "chain " + report.network;
  const when = document.getElementById("generated-at");
  const at = report.generatedAt ? new Date(report.generatedAt) : null;
  when.textContent = at ? at.toLocaleString() : "";
}

function renderInvariants(report) {
  const grid = document.getElementById("invariants");
  grid.textContent = "";
  for (const item of report.invariants) {
    const card = el("div", "invariant-card");
    card.appendChild(el("span", "inv-id", item.id));
    card.appendChild(el("span", "inv-name", item.name));
    const ok = item.status === PASS;
    const status = el("span", "inv-status " + (ok ? "pass" : "fail"));
    status.setAttribute("role", "img");
    status.setAttribute(
      "aria-label",
      `${item.id} ${item.name}: ${item.status}`,
    );
    status.appendChild(el("span", null, (ok ? "\u2714 " : "\u2718 ") + item.status));
    card.appendChild(status);
    card.appendChild(
      el(
        "span",
        "inv-offenders",
        item.offenders.length
          ? `${item.offenders.length} offending record${item.offenders.length === 1 ? "" : "s"}`
          : "no offenders",
      ),
    );
    grid.appendChild(card);
  }
}

function renderRecords(report) {
  const body = document.getElementById("records-body");
  body.textContent = "";
  for (const row of report.records) {
    const tr = el("tr", "row-" + row.status);
    tr.appendChild(el("td", "mono", shortAddress(row.key)));
    tr.appendChild(el("td", null, row.label));

    const v1 = el("td", "mono");
    if (row.v1) {
      v1.appendChild(document.createTextNode(shortAddress(row.v1.owner)));
      v1.appendChild(el("br"));
      v1.appendChild(el("small", null, "expiry " + row.v1.expiry));
    } else {
      v1.className += " cell-empty";
      v1.textContent = "absent";
    }

    const v2 = el("td", "mono");
    if (row.v2) {
      v2.appendChild(document.createTextNode(shortAddress(row.v2.owner)));
      v2.appendChild(el("br"));
      v2.appendChild(el("small", null, "expiry " + row.v2.expiry));
    } else {
      v2.className += " cell-empty";
      v2.textContent = "never migrated";
    }

    tr.appendChild(v1);
    tr.appendChild(v2);

    const chip = el("td");
    const status = el("span", "status-chip " + row.status, row.status);
    chip.appendChild(status);
    tr.appendChild(chip);

    body.appendChild(tr);
  }
}

function renderFooter(report) {
  const v1chip = document.getElementById("addr-v1");
  const v2chip = document.getElementById("addr-v2");
  setupChip(v1chip, report.v1Address, "chip-v1", "v1");
  setupChip(v2chip, report.v2Address, "chip-v2", "v2");
}

function setupChip(node, address, extraClass, label) {
  node.className = "address-chip mono " + extraClass;
  node.textContent = `${label}: ${shortAddress(address || "")}`;
  node.title = address || "";
  node.setAttribute("role", "button");
  node.setAttribute("tabindex", "0");
  node.setAttribute("aria-label", `Registry${label} address ${address}, click to copy`);
  const copy = () => {
    if (!address) return;
    navigator.clipboard.writeText(address);
    const previous = node.textContent;
    node.textContent = "copied!";
    setTimeout(() => {
      node.textContent = `${label}: ${shortAddress(address)}`;
    }, 1200);
  };
  node.addEventListener("click", copy);
  node.addEventListener("keydown", (e) => {
    if (e.key === "Enter" || e.key === " ") copy();
  });
}

function reportUrl() {
  const params = new URLSearchParams(location.search);
  return params.get("report") || "report.json";
}

async function init() {
  try {
    const response = await fetch(reportUrl());
    if (!response.ok) throw new Error("HTTP " + response.status);
    render(await response.json());
  } catch (error) {
    const banner = document.getElementById("status-banner");
    banner.className = "status-banner";
    document.getElementById("banner-text").textContent =
      "open a report.json to view";
    document.getElementById("file-input").click();
  }
}

function onFileChosen(event) {
  const file = event.target.files && event.target.files[0];
  if (!file) return;
  file.text().then((json) => render(JSON.parse(json)));
}

document.getElementById("file-input").addEventListener("change", onFileChosen);
init();
