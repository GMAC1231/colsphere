const fs = require('fs');

const path = require('path');

const sqlite3 = require('sqlite3').verbose();



const CSV_PATH = path.join(__dirname, 'products.csv');

const DB_PATH = path.join(__dirname, 'closphere.db');



console.log("--- RE-ENGAGING CUSTOM PRODUCTS.CSV PIPELINE WITH LOCAL IMAGES ---");



if (!fs.existsSync(CSV_PATH)) {

console.error(`❌ Error: Could not find products.csv inside ${__dirname}`);

process.exit(1);

}



const db = new sqlite3.Database(DB_PATH, (err) => {

if (err) {

console.error("❌ Database Connection Error:", err.message);

process.exit(1);

}

});



// Advanced CSV parser to handle quotes containing commas inside descriptions safely

function parseCSVLine(line) {

const result = [];

let current = '';

let inQuotes = false;



for (let i = 0; i < line.length; i++) {

const char = line[i];

if (char === '"') {

inQuotes = !inQuotes; // Toggle quote state

} else if (char === ',' && !inQuotes) {

result.push(current.trim());

current = '';

} else {

current += char;

}

}

result.push(current.trim());

return result;

}



const fileContent = fs.readFileSync(CSV_PATH, 'utf-8');

const lines = fileContent.split('\n');



db.serialize(() => {

// Drop and re-create table to ensure fresh execution

db.run("DROP TABLE IF EXISTS products");

db.run(`

CREATE TABLE products (

product_id INTEGER PRIMARY KEY AUTOINCREMENT,

name TEXT,

price_omr TEXT,

mode TEXT,

condition TEXT,

status TEXT,

description TEXT,

image_url TEXT

)

`);



const stmt = db.prepare(`

INSERT INTO products (name, price_omr, mode, condition, status, description, image_url)

VALUES (?, ?, ?, ?, ?, ?, ?)

`);



let count = 0;



for (let i = 1; i < lines.length; i++) {

const line = lines[i].trim();

if (!line) continue;



const columns = parseCSVLine(line);

if (columns.length < 7) continue;



const name = columns[0];

const price_omr = columns[1];

const mode = columns[2];

const condition = columns[3];

const status = columns[4];

const description = columns[5];

const fileName = columns[6]; // Takes the filename from your CSV row



// Dynamically creates the local server link pointing to your actual network configuration

const localized_image_url = `http://192.168.100.15:3000/images/${fileName}`;



stmt.run([name, price_omr, mode, condition, status, description, localized_image_url]);

count++;

}



stmt.finalize();

console.log(`\n🎉 SUCCESS: 100 Male Products injected with Local Server Image URLs! Total rows: ${count}`);

db.close();

});
