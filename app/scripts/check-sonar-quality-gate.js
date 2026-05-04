const http = require("http");
const fs = require("fs");

const reportTaskPath = process.argv[2] || "/tmp/sonar-feastops/report-task.txt";
const token = process.env.SONAR_TOKEN;

if (!token) {
  throw new Error("SONAR_TOKEN is required to check the SonarQube Quality Gate");
}

function readReportTask(filePath) {
  const content = fs.readFileSync(filePath, "utf8");
  return Object.fromEntries(
    content
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => {
        const separator = line.indexOf("=");
        return [line.slice(0, separator), line.slice(separator + 1)];
      })
  );
}

function getJson(url) {
  const auth = Buffer.from(`${token}:`).toString("base64");

  return new Promise((resolve, reject) => {
    const request = http.get(url, {
      headers: {
        Authorization: `Basic ${auth}`
      }
    }, (response) => {
      let body = "";

      response.on("data", (chunk) => {
        body += chunk;
      });

      response.on("end", () => {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          reject(new Error(`SonarQube API returned ${response.statusCode}: ${body}`));
          return;
        }

        resolve(JSON.parse(body));
      });
    });

    request.on("error", reject);
  });
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const report = readReportTask(reportTaskPath);
  const ceTaskUrl = report.ceTaskUrl;

  if (!ceTaskUrl) {
    throw new Error(`Could not find ceTaskUrl in ${reportTaskPath}`);
  }

  for (let attempt = 1; attempt <= 30; attempt += 1) {
    const ceTask = await getJson(ceTaskUrl);
    const status = ceTask.task.status;

    console.log(`SonarQube Compute Engine status: ${status}`);

    if (status === "SUCCESS") {
      const gateUrl = `${report.serverUrl}/api/qualitygates/project_status?analysisId=${ceTask.task.analysisId}`;
      const gate = await getJson(gateUrl);
      const gateStatus = gate.projectStatus.status;

      console.log(`SonarQube Quality Gate: ${gateStatus}`);

      if (gateStatus !== "OK") {
        throw new Error(`SonarQube Quality Gate failed with status ${gateStatus}`);
      }

      return;
    }

    if (status === "FAILED" || status === "CANCELED") {
      throw new Error(`SonarQube Compute Engine task ended with status ${status}`);
    }

    await wait(5000);
  }

  throw new Error("Timed out waiting for SonarQube Quality Gate result");
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
