
import puppeteer, { Browser, Page } from 'puppeteer';
import { promises as fs } from 'fs';
import path from 'path';
import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

// --- TYPES ---
interface Publication {
  reg: string;
  type: string;
  subject: string;
  publicationDate: string;
  link: string;
  keyword: string;
}

interface Config {
  keywords: string[];
  emails: string[];
}

// --- CONSTANTS ---
const BASE_URL = 'https://cloud.urbi.it/urbi/progs/urp/';
const SEARCH_PAGE_URL = `${BASE_URL}ur1ME002.sto?DB_NAME=l200130&w3c=1`;
const CONFIG_PATH = path.join(__dirname, 'config.json');
const SEEN_PUBS_PATH = path.join(__dirname, 'seen_publications.json');

const SIGN_OFFS = [
  'Semper vigilans.',
  'Praetorianus civitatem servat.',
  'Custos urbis numquam dormit.',
  'Ad honorem et gloriam Praetoriani.',
  'Praesidium civium fideliter.',
  'Praetorianus in aeternum vigilat.',
  'In umbra gladii libertas custoditur.',
  'Custos urbis facibus noctis lucet.',
  'Silentio defendit, clamque observat.',
  'Fides ferrumque Praetorii sunt arma.',
  'Pro civibus, contra tenebras.',
  'Vita praesidii, honor imperii.',
  'Non dormio dum populus quiescit.',
  'Praetorianus pro muris et foris.',
  'Lux matutina Praetoriano respondet.',
  'Clangor tubae, paratus Praetorianus.',
  'Contumax iniuria sub gladio cadit.',
  'Pax servata, virtus declarata.',
  'Aeterna tutela in corde Praetorii.',
  'Miles urbanus, animus firmus.',
  'Securitas populi, laus Praetorii.',
  'Firmus adversus omnem tumultum.',
  'Nihil timet, qui civitatem amat.',
  'Praetorianus stat, hostis corruit.',
  'Ardens custodia sine fine vigilat.',
];

const PRAETORIAN_VERSION = 'v1.1.0';
const PRAETORIAN_IMAGE_URL = 'https://upload.wikimedia.org/wikipedia/commons/5/5c/Portrait_of_a_praetorian_in_the_Museo_Nazionale_Romano_alle_Terme_2014-12-05.jpg';

// --- MAIN LOGIC ---

/**
 * Loads configuration from config.json
 */
async function loadConfig(): Promise<Config> {
  try {
    const data = await fs.readFile(CONFIG_PATH, 'utf-8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error reading config.json. Make sure the file exists and is valid.', error);
    throw new Error('Config file not found or invalid.');
  }
}

/**
 * Loads the set of seen publication registry IDs.
 */
async function loadSeenPublications(): Promise<Set<string>> {
  try {
    const data = await fs.readFile(SEEN_PUBS_PATH, 'utf-8');
    return new Set(JSON.parse(data));
  } catch (error) {
    const err = error as NodeJS.ErrnoException;
    // If the file doesn't exist, it's the first run. Return an empty set.
    if (err.code === 'ENOENT') {
      return new Set();
    }
    throw err;
  }
}

/**
 * Saves the updated set of seen publication registry IDs.
 */
async function saveSeenPublications(seenPubs: Set<string>): Promise<void> {
  await fs.writeFile(SEEN_PUBS_PATH, JSON.stringify(Array.from(seenPubs)), 'utf-8');
}

/**
 * Scrapes publications for a given keyword.
 */
async function scrapeForKeyword(page: Page, keyword: string): Promise<Publication[]> {
  console.log(`Searching for keyword: "${keyword}"`);
  await page.goto(SEARCH_PAGE_URL, { waitUntil: 'networkidle2' });

  await page.waitForSelector('input[name="Oggetto"]');
  await page.evaluate(() => {
    const input = document.querySelector<HTMLInputElement>('input[name="Oggetto"]');
    if (input) {
      input.value = '';
    }
  });
  await page.type('input[name="Oggetto"]', keyword);

  await page.evaluate(() => {
    const archivio = document.querySelector<HTMLInputElement>('input[name="Archivio"]');
    if (archivio) {
      archivio.value = 'S';
    }

    type WindowWithLibs = typeof window & {
      ctx?: { doStep: (stepper: unknown, action: string) => void };
      $?: (selector: string) => unknown;
    };

    const win = window as WindowWithLibs;
    const ctxObj = win.ctx;
    const jqueryFn = typeof win.$ === 'function' ? win.$ : null;
    const stepper = jqueryFn ? jqueryFn('#idStepper1') : null;

    if (ctxObj && stepper) {
      ctxObj.doStep(stepper, 'avanti');
    } else {
      const form = document.forms.namedItem('Form0');
      if (form) {
        const url = new URL(window.location.href);
        url.searchParams.set('StwEvent', '910001');
        form.setAttribute('action', url.toString());
        form.submit();
      }
    }
  });

  await page.waitForFunction(() => {
    const stepContainer = document.querySelector('#idStepper1_2');
    if (!stepContainer) {
      return false;
    }
    const tableBody = stepContainer.querySelector('#idTabella2 tbody');
    return !!tableBody && tableBody.childElementCount > 0;
  }, { timeout: 60000 });

  const baseUrlForLinks = BASE_URL;

  const publications = await page.$$eval('#idTabella2 tbody tr', (rows, kw, baseUrlString) => {
    return rows.map(row => {
      const tr = row as HTMLTableRowElement;
      const cells = tr.querySelectorAll('td');
      if (cells.length < 2) {
        return null;
      }

      const infoCell = cells[1];
      const strongElements = Array.from(infoCell.querySelectorAll('strong'));
      const type = strongElements[1]?.textContent?.trim() || '';
      const subject = strongElements[2]?.textContent?.trim()
        || strongElements[1]?.textContent?.trim()
        || infoCell.textContent?.trim()
        || '';

      const textContent = infoCell.textContent || '';
      const lines = textContent.split('\n').map(line => line.trim()).filter(Boolean);
      const publicationLine = lines.find(line => line.toLowerCase().startsWith('in pubblicazione dal')) || '';

      const dateMatch = publicationLine.match(/in pubblicazione dal\s*([\d-]+)/i);
      const regMatch = publicationLine.match(/\(reg\.\s*([^\)]+)\)/i);

      const button = tr.querySelector<HTMLButtonElement>('button[data-w3cbt-button-modale-url]');
      let link = '';
      if (button) {
        const relativeUrl = button.getAttribute('data-w3cbt-button-modale-url') || '';
        try {
          const absoluteUrl = new URL(relativeUrl, baseUrlString as string);
          if (!absoluteUrl.searchParams.has('DB_NAME')) {
            absoluteUrl.searchParams.set('DB_NAME', 'l200130');
          }
          link = absoluteUrl.toString();
        } catch (error) {
          link = relativeUrl;
        }
      }

      if (!regMatch || !regMatch[1]) {
        return null;
      }

      return {
        reg: regMatch[1].trim(),
        type: type || 'N/A',
        subject: subject || 'Oggetto non trovato',
        publicationDate: dateMatch ? dateMatch[1].trim() : 'N/A',
        link,
        keyword: kw,
      };
    }).filter((item): item is Publication => Boolean(item));
  }, keyword, baseUrlForLinks);
  return publications;
}

/**
 * Sends an email notification with the new publications.
 */
async function sendNotification(newPublications: Publication[], config: Config): Promise<void> {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    console.warn('SMTP environment variables not set. Skipping email notification.');
    return;
  }

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  const testRecipient = (process.env.PRAETORIAN_TEST_RECIPIENT || '').trim();
  const recipients = testRecipient ? [testRecipient] : config.emails;
  const toHeader = recipients.join(', ');

  const publicationsHtml = newPublications.map(p => `
    <div style="border-bottom: 1px solid #ddd; padding: 15px 0;">
      <p><strong>Oggetto:</strong> ${p.subject}</p>
      <p><strong>Tipologia:</strong> ${p.type}</p>
      <p><strong>Data Pubblicazione:</strong> ${p.publicationDate}</p>
      <p><strong>Riferimento:</strong> ${p.reg} (Trovato con keyword: "${p.keyword}")</p>
      ${p.link ? `<p><a href="${p.link}" style="color: #007bff;">Vedi Pubblicazione</a></p>` : ''}
    </div>
  `).join('');

  const signOff = SIGN_OFFS[Math.floor(Math.random() * SIGN_OFFS.length)];

  const mailOptions = {
    from: `"Praetorian" <${process.env.SMTP_USER}>`,
    to: toHeader,
    subject: 'Praetorian: Nuovi atti pubblicati sull\'Albo Pretorio',
    html: `
      <div style="font-family: sans-serif; color: #333;">
        <h2>Ave, sono Praetorian ${PRAETORIAN_VERSION}, e sorveglio la mia città.</h2>
        <p style="margin-top: 4px; color: #666; font-size: 14px;">Versione ${PRAETORIAN_VERSION} · Guardia Pretoriana digitale al servizio del quartiere.</p>
        <p>Sono stati trovati ${newPublications.length} nuovi atti di potenziale interesse:</p>
        ${publicationsHtml}
        <div style="margin-top: 25px; text-align: center;">
          <img src="${PRAETORIAN_IMAGE_URL}" alt="Ritratto di un pretoriano romano" style="max-width: 220px; width: 100%; border-radius: 8px; box-shadow: 0 0 8px rgba(0,0,0,0.15);" />
        </div>
        <p style="margin-top: 15px; font-style: italic; text-align: center;">${signOff}</p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
  const logRecipients = testRecipient ? `${testRecipient} (test override)` : toHeader;
  if (testRecipient) {
    console.log(`Email notification sent in test mode to: ${logRecipients}`);
  } else {
    console.log(`Email notification sent to: ${logRecipients}`);
  }
}


/**
 * Main function to run the scraper.
 */
async function main() {
  console.log('Praetorian waking up...');
  const config = await loadConfig();
  const seenPubs = await loadSeenPublications();
  const allFoundPublications: Publication[] = [];
  
  let browser: Browser | null = null;
  try {
    browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    const page = await browser.newPage();

    for (const keyword of config.keywords) {
      const publications = await scrapeForKeyword(page, keyword);
      allFoundPublications.push(...publications);
      await new Promise(resolve => setTimeout(resolve, 1000)); // Small delay
    }
  } catch (error) {
    console.error('An error occurred during scraping:', error);
  } finally {
    if (browser) {
      await browser.close();
    }
  }

  const newPublications: Publication[] = [];
  const uniquePubs = new Map<string, Publication>();
  allFoundPublications.forEach(p => {
    if (!uniquePubs.has(p.reg)) {
        uniquePubs.set(p.reg, p);
    }
  });

  for (const pub of uniquePubs.values()) {
    if (!seenPubs.has(pub.reg)) {
      newPublications.push(pub);
    }
  }

  console.log(`Found ${allFoundPublications.length} total publications, ${newPublications.length} of which are new.`);

  if (newPublications.length > 0) {
    console.log('New publications:');
    newPublications.forEach(pub => {
      console.log(`- [${pub.reg}] ${pub.subject} | ${pub.type} | ${pub.publicationDate} | ${pub.link || 'no link'} (keyword: ${pub.keyword})`);
    });

    try {
      await sendNotification(newPublications, config);
      newPublications.forEach(p => seenPubs.add(p.reg));
      await saveSeenPublications(seenPubs);
      console.log('Updated seen publications state.');
    } catch (error) {
      console.error('Failed to send notification or save state:', error);
    }
  }

  console.log('Praetorian going back to sleep.');
}

main().catch(console.error);
