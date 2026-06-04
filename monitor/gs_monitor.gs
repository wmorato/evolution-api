/**
 * ECOSSISTEMA DE MONITORAMENTO MORATO SOLUÇÕES
 * Agent Beta - Consenso Inteligente de Polling Serverless
 * Versão: 2.2.0 — WhatsApp + Telegram
 * 
 * COMO USAR:
 * 1. Google Sheets → Extensões → Apps Script
 * 2. Cole este código
 * 3. Configure as credenciais WA abaixo
 * 4. Vá em "Disparadores" (⏰) → "Ativar disparador"
 *    → checkServerHealth → a cada 1 minuto
 * 5. Execute uma vez para autorizar permissões
 */

// CONFIGURAÇÕES GERAIS
const CONFIG = {
  API_URL: "https://moratosolucoes.com.br/api/v1/health-aggregator",
  MONITOR_TOKEN: "d7a9b0c5e6f7890123456789abcdef01",

  // --- Telegram (existente) ---
  TELEGRAM_BOT_TOKEN: "8788467753:AAFFkPxA_BCuc75-7CxIUxO67WR4wciHOPU",
  TELEGRAM_CHAT_ID: "-5248284816",

  // --- WhatsApp via Evolution API (NOVO) ---
  WA_API_URL: "https://evolution.moratosolucoes.com.br",
  WA_INSTANCE: "MS_Morato",
  WA_APIKEY: "F49763A794EB-4ACE-8523-EA1B7FD29216",
  WA_GROUP_JID: "120363409484120144@g.us"    // Grupo Server_notification
};


/**
 * Função principal executada a cada 1 minuto via Trigger temporal.
 */
function checkServerHealth() {
  const properties = PropertiesService.getScriptProperties();
  const now = new Date();
  const timestampStr = Utilities.formatDate(now, "America/Sao_Paulo", "yyyy-MM-dd HH:mm:ss");

  const sheetApp = SpreadsheetApp.getActiveSpreadsheet();
  const histSheet = sheetApp.getSheetByName("Histórico");
  const incSheet = sheetApp.getSheetByName("Incidentes");

  if (!histSheet || !incSheet) {
    Logger.log("Erro: Abas 'Histórico' ou 'Incidentes' não encontradas na planilha.");
    return;
  }

  let consecutiveFailures = parseInt(properties.getProperty("CONSECUTIVE_FAILURES") || "0", 10);
  let incidentActive = properties.getProperty("INCIDENT_ACTIVE") === "true";
  let incidentNotified = properties.getProperty("INCIDENT_NOTIFIED") === "true";
  let incidentStart = properties.getProperty("INCIDENT_START") || "";
  let lastFailureType = properties.getProperty("LAST_FAILURE_TYPE") || "";
  let lastFailureDetails = properties.getProperty("LAST_FAILURE_DETAILS") || "";

  const options = {
    method: "get",
    headers: { "x-monitor-token": CONFIG.MONITOR_TOKEN },
    muteHttpExceptions: true,
    connectTimeout: 10000,
    readTimeout: 15000
  };

  const startTime = new Date().getTime();
  let responseCode = 0;
  let statusGeral = "OFFLINE";
  let servicesCount = 0;
  let falhas = [];

  try {
    const response = UrlFetchApp.fetch(CONFIG.API_URL, options);
    const endTime = new Date().getTime();
    const latency = endTime - startTime;
    responseCode = response.getResponseCode();
    const responseText = response.getContentText();

    if (responseCode === 200) {
      const payload = JSON.parse(responseText);
      statusGeral = payload.status_geral || "ERROR";
      falhas = payload.falhas || [];
      servicesCount = payload.services_count || 0;

      histSheet.appendRow([timestampStr, statusGeral, latency, servicesCount, falhas.join(", ")]);

      if (statusGeral === "OK") {
        if (incidentActive) {
          const durationMin = calculateDurationMinutes(incidentStart, now);

          incSheet.appendRow([incidentStart, timestampStr, durationMin, lastFailureType, lastFailureDetails]);

          // --- NOTIFICA RESTAURAÇÃO: Telegram + WhatsApp ---
          const msg =
            "*SISTEMA OPERACIONAL*\n\n" +
            "Servidor: Contabo-VPS-01\n" +
            "Status: 100% Online\n" +
            "Tempo Fora: " + durationMin + " minutos\n" +
            "Timestamp: " + timestampStr;

          sendTelegramNotification("✅ " + msg);
          sendWhatsAppNotification("✅ SISTEMA OPERACIONAL\n\n" +
            "Servidor: Contabo-VPS-01\n" +
            "Status: 100% Online\n" +
            "Tempo Fora: " + durationMin + " min\n" +
            "Timestamp: " + timestampStr);
        }

        properties.setProperties({
          "CONSECUTIVE_FAILURES": "0",
          "INCIDENT_ACTIVE": "false",
          "INCIDENT_NOTIFIED": "false",
          "INCIDENT_START": "",
          "LAST_FAILURE_TYPE": "",
          "LAST_FAILURE_DETAILS": ""
        });
      } else {
        consecutiveFailures++;
        properties.setProperty("CONSECUTIVE_FAILURES", consecutiveFailures.toString());

        if (consecutiveFailures >= 3 && !incidentNotified) {
          incidentActive = true;
          incidentNotified = true;
          incidentStart = incidentStart || timestampStr;
          const failureDetails = falhas.join(", ");

          properties.setProperties({
            "INCIDENT_ACTIVE": "true",
            "INCIDENT_NOTIFIED": "true",
            "INCIDENT_START": incidentStart,
            "LAST_FAILURE_TYPE": "QUEDA PARCIAL",
            "LAST_FAILURE_DETAILS": failureDetails
          });

          // --- NOTIFICA QUEDA PARCIAL: Telegram + WhatsApp ---
          sendTelegramNotification(
            "🚨 *ALERTA: QUEDA PARCIAL DE CONTÊINERES*\n\n" +
            "Servidor: Contabo-VPS-01\n" +
            "Gravidade: ALTA\n" +
            "Falhas Detectadas:\n" + falhas.map(function(f) { return "  - " + f; }).join("\n") + "\n" +
            "Timestamp: " + timestampStr + "\n" +
            "_Alerta disparado após 3 coletas consecutivas de falha._"
          );

          sendWhatsAppNotification(
            "⚠️ ALERTA: QUEDA PARCIAL\n\n" +
            "Servidor: Contabo-VPS-01\n" +
            "Falhas:\n" + falhas.map(function(f) { return "  - " + f; }).join("\n") + "\n" +
            "Timestamp: " + timestampStr);
        }
      }
    } else {
      throw new Error("HTTP " + responseCode + " recebido do proxy reverso.");
    }
  } catch (err) {
    const endTime = new Date().getTime();
    const latency = endTime - startTime;
    consecutiveFailures++;

    properties.setProperty("CONSECUTIVE_FAILURES", consecutiveFailures.toString());

    histSheet.appendRow([timestampStr, "OFFLINE", latency, 0, "ERRO DE REDE: " + err.message]);

    if (consecutiveFailures >= 3 && !incidentNotified) {
      incidentActive = true;
      incidentNotified = true;
      incidentStart = incidentStart || timestampStr;

      properties.setProperties({
        "INCIDENT_ACTIVE": "true",
        "INCIDENT_NOTIFIED": "true",
        "INCIDENT_START": incidentStart,
        "LAST_FAILURE_TYPE": "QUEDA TOTAL",
        "LAST_FAILURE_DETAILS": err.message
      });

      // --- NOTIFICA QUEDA TOTAL: Telegram + WhatsApp ---
      sendTelegramNotification(
        "💥 *ALERTA CRÍTICO: SERVIDOR VPS INACESSÍVEL*\n\n" +
        "Servidor: Contabo-VPS-01\n" +
        "Gravidade: CRÍTICA\n" +
        "Causa: Queda total da VPS ou Rede Inacessível\n" +
        "Erro: " + err.message + "\n" +
        "Timestamp: " + timestampStr + "\n" +
        "_Alerta disparado após 3 coletas consecutivas de timeout/rede._"
      );

      sendWhatsAppNotification(
        "🔴 ALERTA CRÍTICO: SERVIDOR INACESSÍVEL\n\n" +
        "Servidor: Contabo-VPS-01\n" +
        "Gravidade: CRÍTICA\n" +
        "Erro: " + err.message + "\n" +
        "Timestamp: " + timestampStr);
    }
  }
}


/**
 * Envia notificação para o grupo do WhatsApp via Evolution API.
 * =================================================================
 * FUNÇÃO NOVA — adiciona redundância ao Telegram.
 * Se o Evolution API estiver no mesmo servidor monitorado,
 * esta notificação pode falhar junto com o serviço principal.
 * O Telegram continua como fallback externo.
 * =================================================================
 */
function sendWhatsAppNotification(text) {
  var apikey = CONFIG.WA_APIKEY;
  var url = CONFIG.WA_API_URL + "/message/sendText/" + CONFIG.WA_INSTANCE;

  var payload = {
    number: CONFIG.WA_GROUP_JID,
    text: text
  };

  var options = {
    method: "post",
    contentType: "application/json",
    headers: {
      "apikey": apikey
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  try {
    var response = UrlFetchApp.fetch(url, options);
    var result = JSON.parse(response.getContentText());
    if (result.status === "PENDING") {
      Logger.log("WhatsApp: notificação enviada para o grupo.");
    } else {
      Logger.log("WhatsApp: resposta inesperada: " + response.getContentText());
    }
  } catch (err) {
    Logger.log("WhatsApp: erro ao enviar notificação: " + err.message);
  }
}


/**
 * Envia notificação via Telegram Bot API (existente)
 */
function sendTelegramNotification(message) {
  var botToken = CONFIG.TELEGRAM_BOT_TOKEN;
  var chatId = CONFIG.TELEGRAM_CHAT_ID;

  if (botToken.indexOf("SEU_") === 0 || chatId.indexOf("SEU_") === 0) {
    Logger.log("Telegram: credenciais não configuradas.");
    return;
  }

  var url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
  var payload = {
    chat_id: chatId,
    text: message,
    parse_mode: "Markdown"
  };

  var options = {
    method: "post",
    contentType: "application/json",
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  try {
    UrlFetchApp.fetch(url, options);
  } catch (err) {
    Logger.log("Telegram: erro ao enviar: " + err.message);
  }
}


/**
 * Calcula a diferença em minutos entre duas datas
 */
function calculateDurationMinutes(startStr, endDate) {
  var start = new Date(startStr.replace(/-/g, "/"));
  var diffMs = Math.abs(endDate.getTime() - start.getTime());
  return Math.round(diffMs / 1000 / 60);
}
