import os
import sys
import time
import json
import re
import sqlite3
import threading
import winsound
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import customtkinter as ctk
import pandas as pd
import pyautogui
import pyperclip
import keyboard
import requests

# នាំចូលបណ្ណាល័យក្រៅជាជម្រើស (Optional Modules)
import pdfplumber

try:
    from converter_ui import UXAutoInputPro  # type: ignore
except ImportError:
    UXAutoInputPro = None

try:
    from create_customer import CreateCustomerDialog  # type: ignore
except ImportError:
    CreateCustomerDialog = None


class UXAutoInputFinal(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)

        self.is_running = False
        self.dry_run = False
        self.converter_window = None

        # Speed & Logic variables
        self.base_wait_code = 1.0
        self.base_wait_commit = 0.7
        self.dynamic_factor = 1.0

        self.project_id = "meter-reading-654c0"
        self.log_db = "auto_input_log.db"
        self.init_log_db()

        self.setup_ui()
        self.after(1000, self.auto_recover_status)

    def write_text(self, text):
        """ វាយអត្ថបទដោយសុវត្ថិភាព គាំទ្រអក្សរខ្មែរ (Unicode) តាមរយៈការ Copy-Paste ឬ keyboard.write """
        text_str = str(text).strip()
        if text_str.replace('.', '', 1).replace('-', '', 1).isdigit():
            keyboard.write(text_str)
            return

        try:
            pyperclip.copy(text)
            pyautogui.hotkey('ctrl', 'v')
        except Exception:
            keyboard.write(text_str)

    # --- មុខងារគ្រប់គ្រង Log History ---
    def init_log_db(self):
        conn = sqlite3.connect(self.log_db)
        cursor = conn.cursor()
        cursor.execute("CREATE TABLE IF NOT EXISTS history (customer_code TEXT PRIMARY KEY, entry_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP)")
        conn.commit()
        conn.close()

    def add_to_log(self, code):
        """ កត់ត្រាកូដដែលបញ្ចូលរួចរាល់ចូលក្នុង SQLite """
        try:
            conn = sqlite3.connect(self.log_db)
            cursor = conn.cursor()
            cursor.execute("INSERT OR IGNORE INTO history (customer_code) VALUES (?)", (str(code).strip(),))
            conn.commit()
            conn.close()
        except Exception:
            pass

    def auto_recover_status(self):
        """ ឆែកមើលតារាង ហើយប្រៀបធៀបជាមួយ Log បើធ្លាប់ធ្វើរួច ឱ្យចេញពណ៌បៃតងភ្លាម """
        all_items = self.tree.get_children()
        if not all_items:
            return

        conn = sqlite3.connect(self.log_db)
        cursor = conn.cursor()
        cursor.execute("SELECT customer_code FROM history")
        done_codes = {str(row[0]).strip() for row in cursor.fetchall()}
        conn.close()

        recovered_count = 0
        for item in all_items:
            code = str(self.tree.item(item, 'values')[1]).strip()
            if code in done_codes:
                self.tree.item(item, tags=('done',))
                recovered_count += 1

        self.update_stats()
        if recovered_count > 0:
            messagebox.showinfo(
                "🔄 ស្តារប្រវត្តិការងារ (Auto Resume)",
                f"បានរកឃើញ និងស្តារប្រវត្តិបញ្ចូលចាស់ចំនួន {recovered_count} នាក់ (ចេញពណ៌បៃតង)!\n\n"
                f"ប្រព័ន្ធនឹងរំលងអតិថិជនទាំងនេះស្វ័យប្រវត្តិ ហើយចាប់ផ្ដើមបញ្ចូលបន្តពីជួរដែលនៅសល់។",
                parent=self
            )

    def clear_history_db(self):
        """ លុបប្រវត្តិក្នុង Log ចោល (សម្រាប់ចាប់ផ្តើមការងារថ្មីស្រឡាង) """
        if messagebox.askyesno("Confirm", "តើអ្នកចង់លុបប្រវត្តិបញ្ចូលចាស់ៗក្នុង Log ចោលមែនទេ?", parent=self):
            conn = sqlite3.connect(self.log_db)
            cursor = conn.cursor()
            cursor.execute("DELETE FROM history")
            conn.commit()
            conn.close()
            # Refresh តារាងឱ្យបាត់ពណ៌បៃតង
            for item in self.tree.get_children():
                self.tree.item(item, tags=())
            self.update_stats()
            messagebox.showinfo("Success", "បានសម្អាត Log រួចរាល់!")

    def setup_ui(self):
        # --- ផ្នែកបញ្ជាខាងលើ (Top Controls) ---
        self.top_frame = ctk.CTkFrame(self)
        self.top_frame.pack(fill="x", padx=20, pady=10)

        self.search_var = ctk.StringVar()
        self.search_entry = ctk.CTkEntry(self.top_frame, placeholder_text="🔍 ស្វែងរកកូដ...", textvariable=self.search_var, width=180)
        self.search_entry.pack(side="right", padx=10)
        self.search_entry.bind("<Return>", self.search_and_focus)

        ctk.CTkButton(self.top_frame, text="☁️ ទាញពី Cloud", fg_color="#009688", width=110, font=("Khmer OS Battambang", 13), command=self.import_firebase_cloud).pack(side="left", padx=4)
        ctk.CTkButton(self.top_frame, text="🧪 Dry Run", fg_color="#7f8c8d", width=90, font=("Khmer OS Battambang", 13), command=self.toggle_dry_run).pack(side="left", padx=4)
        ctk.CTkButton(self.top_frame, text="📥 បើក Excel", width=95, font=("Khmer OS Battambang", 13), command=self.import_excel).pack(side="left", padx=4)
        ctk.CTkButton(self.top_frame, text="📲 ទាញពី .db", width=95, fg_color="#3498db", font=("Khmer OS Battambang", 13), command=self.import_db).pack(side="left", padx=4)
        ctk.CTkButton(self.top_frame, text="📄 PDF", width=75, fg_color="#e67e22", font=("Khmer OS Battambang", 13), command=self.import_pdf).pack(side="left", padx=4)

        # --- ផ្នែកប៊ូតុងគ្រប់គ្រងតារាង (Table Actions) ---
        self.action_frame = ctk.CTkFrame(self)
        self.action_frame.pack(fill="x", padx=20, pady=5)

        ctk.CTkButton(self.action_frame, text="✅ ជ្រើសទាំងអស់", fg_color="#27ae60", font=("Khmer OS Battambang", 13), command=self.select_all).pack(side="left", padx=4)
        ctk.CTkButton(self.action_frame, text="❌ ដោះជ្រើសទាំងអស់", fg_color="#7f8c8d", font=("Khmer OS Battambang", 13), command=self.deselect_all).pack(side="left", padx=4)
        ctk.CTkButton(self.action_frame, text="🧹 លុបជួររួចរាល់", fg_color="#8e44ad", font=("Khmer OS Battambang", 13), command=self.clear_done_items).pack(side="left", padx=4)
        ctk.CTkButton(self.action_frame, text="📊 ទាញចេញ Excel", fg_color="#2c3e50", font=("Khmer OS Battambang", 13), command=self.export_done_to_excel).pack(side="left", padx=4)
        ctk.CTkButton(self.action_frame, text="⚠️ ទាញចេញបញ្ជីរំលង", fg_color="#f39c12", text_color="black", font=("Khmer OS Battambang", 13), command=self.export_skipped_to_excel).pack(side="left", padx=4)
        ctk.CTkButton(self.action_frame, text="🗑️ សម្អាត Log ចាស់", fg_color="#e67e22", font=("Khmer OS Battambang", 13), command=self.clear_history_db).pack(side="left", padx=4)

        # --- ផ្នែកបង្ហាញស្ថិតិ និង Progress ---
        self.stats_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.stats_frame.pack(fill="x", padx=25, pady=5)
        self.lbl_done_count = ctk.CTkLabel(self.stats_frame, text="រួចរាល់៖ 0", font=("Khmer OS Battambang", 12, "bold"), text_color="#2ecc71")
        self.lbl_done_count.pack(side="left", padx=10)
        self.lbl_remain_count = ctk.CTkLabel(self.stats_frame, text="នៅសល់៖ 0", font=("Khmer OS Battambang", 12, "bold"), text_color="#e74c3c")
        self.lbl_remain_count.pack(side="left", padx=10)

        self.progress = ctk.CTkProgressBar(self, height=15)
        self.progress.pack(fill="x", padx=20, pady=5)
        self.progress.set(0)

        # --- កំណត់ Style សម្រាប់តារាង Treeview ---
        style = ttk.Style()
        style.theme_use("default")

        style.configure(
            "Treeview.Heading",
            font=("Khmer OS Battambang", 11, "bold"),
            background="#2c3e50",
            foreground="white"
        )
        style.configure(
            "Treeview",
            font=("Khmer OS System", 11),
            rowheight=34
        )
        style.map("Treeview", background=[('selected', '#3498db')])

        # --- បង្កើត Treeview ជាមួយ Style ដែលបានកំណត់ ---
        self.tree_frame = ctk.CTkFrame(self)
        self.tree_frame.pack(fill="both", expand=True, padx=20, pady=5)

        self.tree = ttk.Treeview(
            self.tree_frame,
            columns=("check", "code", "name", "box", "meter", "old", "new", "multiplier", "total"),
            show="headings"
        )
        self.tree.heading("check", text="ជ្រើសរើស")
        self.tree.heading("code", text="កូដអតិថិជន")
        self.tree.heading("name", text="ឈ្មោះ")
        self.tree.heading("box", text="ប្រអប់")
        self.tree.heading("meter", text="នាឡិកាស្ទង់")
        self.tree.heading("old", text="អំណានចាស់")
        self.tree.heading("new", text="អំណានថ្មី")
        self.tree.heading("multiplier", text="មេគុណ")
        self.tree.heading("total", text="ថាមពលសរុប")

        self.tree.column("check", width=80, anchor="center")
        self.tree.column("code", width=120, anchor="center")
        self.tree.column("name", width=220, anchor="w")
        self.tree.column("box", width=90, anchor="center")
        self.tree.column("meter", width=120, anchor="center")
        self.tree.column("old", width=100, anchor="e")
        self.tree.column("new", width=100, anchor="e")
        self.tree.column("multiplier", width=80, anchor="center")
        self.tree.column("total", width=110, anchor="center")

        # Scrollbars
        vsb = ttk.Scrollbar(self.tree_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vsb.set)
        self.tree.pack(side="left", fill="both", expand=True)
        vsb.pack(side="right", fill="y")

        # 4. បង្កើត Entry សម្រាប់កែសម្រួល
        self.edit_entry = ctk.CTkEntry(self.tree, corner_radius=0, border_width=2)
        self.edit_entry.bind("<Return>", self.on_enter_pressed)
        self.edit_entry.bind("<FocusOut>", lambda e: self.edit_entry.place_forget())

        # Bindings & Tags
        self.tree.bind("<Double-1>", self.on_double_click)
        self.tree.tag_configure('done', background='#C8E6C9', font=("Khmer OS System", 11, "bold"))
        self.tree.tag_configure('error', background='#FFCDD2')
        self.tree.tag_configure('skipped', background='#FFF59D')

        # --- ផ្នែកបញ្ជាខាងក្រោម (Bottom Controls) ---
        self.bot_frame = ctk.CTkFrame(self)
        self.bot_frame.pack(fill="x", padx=20, pady=10)

        ctk.CTkLabel(self.bot_frame, text="ល្បឿន (Speed):", font=("Khmer OS Battambang", 12)).pack(side="left", padx=10)
        self.speed_slider = ctk.CTkSlider(self.bot_frame, from_=0, to=2)
        self.speed_slider.set(0.25)
        self.speed_slider.pack(side="left", padx=10)

        self.btn_run = ctk.CTkButton(
            self.bot_frame,
            text="🚀 ចាប់ផ្តើមបញ្ចូល",
            fg_color="green",
            width=160,
            font=("Khmer OS Battambang", 14, "bold"),
            command=self.start_automation
        )
        self.btn_run.pack(side="right", padx=10)

        ctk.CTkButton(
            self.bot_frame,
            text="🛑 បញ្ឈប់ (Esc)",
            fg_color="#c0392b",
            width=110,
            font=("Khmer OS Battambang", 14),
            command=self.stop_automation
        ).pack(side="right", padx=10)

    # ================= METHODS =================

    def on_double_click(self, event):
        region = self.tree.identify_region(event.x, event.y)

        if region == "cell":
            column = self.tree.identify_column(event.x)
            item = self.tree.identify_row(event.y)
            col_index = int(column.replace("#", "")) - 1

            if col_index == 0:
                vals = list(self.tree.item(item, 'values'))
                vals[0] = "☑" if vals[0] == "☐" else "☐"
                self.tree.item(item, values=vals)
                self.update_stats()
                return

            if col_index in [6, 7]:
                self.show_edit_entry(item, col_index)

    def show_edit_entry(self, item, col_index):
        """ បង្ហាញប្រអប់វាយអត្ថបទចំពីលើ Cell ឱ្យចំទីតាំងបេះបិទ """
        column_id = f"#{col_index + 1}"
        bbox = self.tree.bbox(item, column_id)

        if bbox:
            x, y, w, h = bbox
            current_vals = self.tree.item(item, "values")
            current_val = str(current_vals[col_index]) if col_index < len(current_vals) else ""

            self.edit_entry.configure(width=w, height=h)
            self.edit_entry.delete(0, "end")
            self.edit_entry.insert(0, current_val)
            self.edit_entry.place(x=x, y=y)
            self.edit_entry.focus_set()
            self.edit_entry.select_range(0, 'end')
            self.editing_item = (item, col_index)
        else:
            self.tree.see(item)

    def on_enter_pressed(self, event):
        if hasattr(self, 'editing_item') and self.edit_entry.winfo_viewable():
            item, col_index = self.editing_item
            new_input = self.edit_entry.get()

            vals = list(self.tree.item(item, "values"))
            vals[col_index] = new_input

            try:
                def to_float(val):
                    if not val or str(val).strip() in ["", "nan", "!"]:
                        return 0.0
                    return float(str(val).replace(',', '').strip())

                old_val = to_float(vals[5])
                new_val = to_float(vals[6])
                multiplier = to_float(vals[7])
                if multiplier <= 0:
                    multiplier = 1.0

                if new_val >= old_val:
                    result = (new_val - old_val) * multiplier
                    vals[8] = f"{result:g}"
                else:
                    vals[8] = "Error"
            except Exception as e:
                print(f"Calc Error: {e}")
                vals[8] = "!"

            self.tree.item(item, values=vals)
            self.edit_entry.place_forget()

            next_item = self.tree.next(item)
            if next_item:
                self.tree.see(next_item)
                self.tree.selection_set(next_item)
                self.show_edit_entry(next_item, col_index)
            else:
                self.focus_set()

    def select_all(self):
        for item in self.tree.get_children():
            vals = list(self.tree.item(item, 'values'))
            vals[0] = "☑"
            self.tree.item(item, values=vals)
        self.update_stats()

    def deselect_all(self):
        for item in self.tree.get_children():
            vals = list(self.tree.item(item, 'values'))
            vals[0] = "☐"
            self.tree.item(item, values=vals)
        self.update_stats()

    def clear_done_items(self):
        all_items = self.tree.get_children()
        count = 0
        for item in all_items:
            if 'done' in self.tree.item(item, 'tags'):
                self.tree.delete(item)
                count += 1
        self.update_stats()
        messagebox.showinfo("Success", f"បានលុប {count} ជួរដែលរួចរាល់!")

    def export_done_to_excel(self):
        done_data = []
        for item in self.tree.get_children():
            if 'done' in self.tree.item(item, 'tags'):
                vals = self.tree.item(item, 'values')
                done_data.append({
                    "កូដ": vals[1],
                    "ឈ្មោះអតិថិជន": vals[2],
                    "ប្រអប់": vals[3],
                    "លេខនាឡិកាស្ទង់": vals[4],
                    "អំណានចាស់": vals[5],
                    "អំណានថ្មី": vals[6]
                })

        if done_data:
            path = filedialog.asksaveasfilename(defaultextension=".xlsx")
            if path:
                pd.DataFrame(done_data).to_excel(path, index=False)
                messagebox.showinfo("Success", "នាំចេញរបាយការណ៍ជោគជ័យ!")
        else:
            messagebox.showwarning("Warning", "គ្មានទិន្នន័យដែលបញ្ចូលរួចទេ!")

    def export_skipped_to_excel(self):
        """ ទាញយកទិន្នន័យដែលមាន Tag 'skipped' (ពណ៌លឿង) ចេញជា Excel """
        skipped_data = []
        for item in self.tree.get_children():
            if 'skipped' in self.tree.item(item, 'tags'):
                vals = self.tree.item(item, 'values')

                meter_val = str(vals[4]).strip().lower()
                is_empty_meter = meter_val in ["", "nan", "-", "none", "null", ".", "nan"]

                try:
                    def clean_number(text):
                        if not text:
                            return None
                        cleaned = str(text).replace(',', '').strip()
                        if cleaned in ["", "nan", "-", "None"]:
                            return None
                        return float(cleaned)
                    o_v = clean_number(vals[5]) or 0.0
                    n_v = clean_number(vals[6])
                    if n_v is None:
                        n_v = -1.0
                except Exception:
                    o_v = 0.0
                    n_v = -1.0

                code_val = str(vals[1]).strip()
                has_letter_code = bool(re.search(r'[a-zA-Z]', code_val))

                if has_letter_code:
                    reason = f"កូដមានអក្សរ ({code_val})"
                elif is_empty_meter:
                    reason = "គ្មានលេខនាឡិកា"
                elif n_v < o_v:
                    reason = f"អំណានថ្មីតូចជាងចាស់ (ថ្មី:{n_v} < ចាស់:{o_v})"
                else:
                    reason = "ពិនិត្យ៖ ទិន្នន័យខុសប្រក្រតី"

                skipped_data.append({
                    "កូដ": vals[1],
                    "ឈ្មោះអតិថិជន": vals[2],
                    "ប្រអប់": vals[3],
                    "លេខនាឡិកាស្ទង់": vals[4],
                    "អំណានចាស់": vals[5],
                    "អំណានថ្មី": vals[6],
                    "មូលហេតុ": reason
                })

        if skipped_data:
            path = filedialog.asksaveasfilename(
                defaultextension=".xlsx",
                filetypes=[("Excel Files", "*.xlsx")],
                title="រក្សាទុកបញ្ជីដែលបានរំលង"
            )
            if path:
                df = pd.DataFrame(skipped_data)
                df.to_excel(path, index=False)
                messagebox.showinfo("ជោគជ័យ", f"បាននាំចេញបញ្ជីរំលងចំនួន {len(skipped_data)} រួចរាល់!")
        else:
            messagebox.showinfo("ព័ត៌មាន", "គ្មានទិន្នន័យដែលត្រូវបានរំលង (Skipped) ក្នុងតារាងទេ!")

    def update_stats(self):
        all_items = self.tree.get_children()
        done = sum(1 for i in all_items if 'done' in self.tree.item(i, 'tags'))
        selected = sum(1 for i in all_items if self.tree.item(i, 'values')[0] == "☑")
        self.lbl_done_count.configure(text=f"រួចរាល់៖ {done}")
        self.lbl_remain_count.configure(text=f"នៅសល់៖ {max(0, selected - done)}")

    def search_and_focus(self, event=None):
        code = self.search_var.get().strip().zfill(6)
        for item in self.tree.get_children():
            if self.tree.item(item, 'values')[1] == code:
                self.tree.see(item)
                self.tree.selection_set(item)
                self.tree.focus(item)
                return

    def toggle_dry_run(self):
        self.dry_run = not self.dry_run
        messagebox.showinfo("Dry Run", f"Mode: {'ON' if self.dry_run else 'OFF'}")

    def open_converter(self):
        if UXAutoInputPro is None:
            messagebox.showinfo("Converter", "Converter UI module មិនទាន់បានភ្ជាប់ទេ!")
            return
        if self.converter_window is None or not self.converter_window.winfo_exists():
            self.converter_window = UXAutoInputPro(self)
        else:
            self.converter_window.focus()

    def open_add_customer(self):
        if CreateCustomerDialog is None:
            messagebox.showinfo("Customer", "CreateCustomerDialog module មិនទាន់បានភ្ជាប់ទេ!")
            return
        dialog = CreateCustomerDialog(
            parent=self,
            callback=lambda data: print(f"Customer saved: {data}")
        )

    # --- ☁️ មុខងារទាញយកពី Firebase Cloud ( Paginated + 429 Quota Handling + Skip Already Done ) ---
    def import_firebase_cloud(self):
        def task():
            try:
                # ០. ទាញយកបញ្ជីកូដអតិថិជនដែលបានបញ្ចូលក្នុង E-POWER រួចរាល់ពី SQLite Log History
                conn = sqlite3.connect(self.log_db)
                cursor = conn.cursor()
                cursor.execute("SELECT customer_code FROM history")
                done_codes = {str(row[0]).strip() for row in cursor.fetchall()}
                conn.close()

                readings_data = []
                already_done_count = 0
                quota_error = False

                # មុខងារជំនួយ៖ ទាញយកតម្លៃពី Firestore Field Object ដោយគាំទ្រ Key ច្រើនទម្រង់
                def extract_val(fields_map, key_list, default_val=""):
                    for key in key_list:
                        if key in fields_map:
                            v_obj = fields_map[key]
                            if isinstance(v_obj, dict):
                                if "stringValue" in v_obj:
                                    return str(v_obj["stringValue"]).strip()
                                if "integerValue" in v_obj:
                                    return str(v_obj["integerValue"]).strip()
                                if "doubleValue" in v_obj:
                                    return str(v_obj["doubleValue"]).strip()
                            elif v_obj is not None:
                                return str(v_obj).strip()
                    return default_val

                documents_list = []

                # ១. សាកល្បង Query តាម Collection Group ( runQuery )
                query_url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents:runQuery"
                query_payload = {
                    "structuredQuery": {
                        "from": [{"collectionId": "readings", "allDescendants": True}],
                        "limit": 1000
                    }
                }
                resp_q = requests.post(query_url, json=query_payload, timeout=10)

                if resp_q.status_code == 200 and isinstance(resp_q.json(), list):
                    for item in resp_q.json():
                        doc = item.get("document")
                        if doc:
                            documents_list.append(doc)
                elif resp_q.status_code == 429:
                    quota_error = True

                # ២. ករណី runQuery មិនបាន ទាញតាម devices listing
                if not documents_list and not quota_error:
                    url_devices = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents/devices?pageSize=300"
                    resp = requests.get(url_devices, timeout=10)
                    if resp.status_code == 429:
                        quota_error = True
                    elif resp.status_code == 200:
                        devices = [d.get("name") for d in resp.json().get("documents", []) if d.get("name")]
                        for d_path in devices:
                            url_r = f"https://firestore.googleapis.com/v1/{d_path}/readings?pageSize=300"
                            resp_r = requests.get(url_r, timeout=10)
                            if resp_r.status_code == 429:
                                quota_error = True
                                break
                            elif resp_r.status_code == 200:
                                documents_list.extend(resp_r.json().get("documents", []))

                # ⚠️ ប្រសិនបើជាប់ Error 429 (Resource Exhausted / Quota Exceeded)
                if quota_error:
                    self.after(0, lambda: messagebox.showerror(
                        "⚠️ ជាប់ Quota Exceeded (429)",
                        "Firebase Cloud ជាប់កម្រិតកំណត់ Google (RESOURCE_EXHAUSTED 429)!\n\n"
                        "💡 ដំណោះស្រាយ៖ សូមប្រើប្រាស់ប៊ូតុង '📲 ទាញពី .db' ដើម្បីនាំចូលហ្វាល់ sn_meter.db ពីទូរស័ព្ទដៃជំនួសវិញ!",
                        parent=self
                    ))
                    return

                for r_doc in documents_list:
                    fields = r_doc.get("fields", {})

                    code_str = extract_val(fields, ["code", "customer_code"], "")
                    name_str = extract_val(fields, ["name", "customer_name"], "")
                    box_str = extract_val(fields, ["box"], "")
                    meter_str = extract_val(fields, ["meter", "meter_no"], "")
                    old_v_str = extract_val(fields, ["old", "old_value", "old_val"], "0")
                    new_v_str = extract_val(fields, ["new", "new_value", "new_val"], "")

                    # 🎯 ១. រំលងប្រសិនបើគ្មានកូដ ឬ គ្មានអំណានថ្មី
                    if not code_str or not new_v_str or new_v_str in ["0", "0.0", "", "none", "null", "nan"]:
                        continue

                    val_code = code_str.zfill(6)

                    # 🎯 ២. រំលងប្រសិនបើកូដនេះធ្លាប់បានបញ្ចូលក្នុង E-POWER រួចរាល់ហើយ!
                    if val_code in done_codes:
                        already_done_count += 1
                        continue

                    # គណនាថាមពលសរុប
                    try:
                        o_num = float(old_v_str.replace(',', '').strip())
                        n_num = float(new_v_str.replace(',', '').strip())
                        total_kwh = f"{(n_num - o_num):g}" if n_num >= o_num else ""
                    except Exception:
                        total_kwh = ""

                    readings_data.append((
                        "☑", val_code, name_str, box_str,
                        meter_str, old_v_str, new_v_str, "1", total_kwh
                    ))

                if readings_data:
                    def update_ui():
                        self.tree.delete(*self.tree.get_children())
                        for row in readings_data:
                            self.tree.insert("", "end", values=row)
                        self.auto_recover_status()
                        msg = f"បានទាញយកទិន្នន័យអតិថិជនថ្មីចំនួន {len(readings_data)} នាក់ ពី Firebase Cloud!"
                        if already_done_count > 0:
                            msg += f"\n(បានរំលង {already_done_count} នាក់ ដែលបានបញ្ចូលក្នុង E-POWER រួចរាល់)"
                        messagebox.showinfo("ជោគជ័យ", msg, parent=self)
                    self.after(0, update_ui)
                else:
                    if already_done_count > 0:
                        self.after(0, lambda: messagebox.showinfo(
                            "គ្រប់គ្រងរួចរាល់",
                            f"អតិថិជនដែលមានអំណានថ្មីទាំងអស់ ({already_done_count} នាក់) ត្រូវបានបញ្ចូលក្នុង E-POWER រួចរាល់ហើយ!\n\n"
                            f"គ្មានអតិថិជនថ្មីត្រូវបញ្ចូលបន្ថែមទៀតទេ។ (ប្រសិនបើចង់បញ្ចូលឡើងវិញ សូមចុច '🗑️ សម្អាត Log ចាស់')",
                            parent=self
                        ))
                    else:
                        self.after(0, lambda: messagebox.showwarning("មិនមានទិន្នន័យអំណានថ្មី", "មិនទាន់មានអតិថិជនណាបានបញ្ចូលអំណានថ្មីក្នុង Firebase ឡើយ។", parent=self))
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("Error", f"មិនអាចទាញយកពី Firebase Cloud ទេ៖ {e}", parent=self))

        threading.Thread(target=task, daemon=True).start()

    def import_db(self):
        path = filedialog.askopenfilename(filetypes=[("Database Files", "*.db")])
        if not path:
            return

        try:
            conn = sqlite3.connect(path)
            df = pd.read_sql_query("SELECT * FROM sn_meter", conn)
            conn.close()

            def clean_num(val):
                try:
                    if not val or str(val).strip() in ["", "nan", "None"]:
                        return 0.0
                    return float(str(val).replace(',', '').strip())
                except Exception:
                    return 0.0

            if df.empty:
                messagebox.showwarning("Warning", "Database គ្មានទិន្នន័យ!")
                return

            cols = df.columns.tolist()
            def find_col(keywords):
                for c in cols:
                    if any(key.lower() in c.lower() for key in keywords):
                        return c
                return None

            c_code = find_col(['code', 'កូដ', 'លេខអតិថិជន'])
            c_name = find_col(['name', 'ឈ្មោះ'])
            c_box = find_col(['box', 'ប្រអប់'])
            c_meter = find_col(['meter', 'នាឡិកា', 'ស៊េរី'])
            c_old = find_col(['old', 'អំណានចាស់', 'ចាស់'])
            c_new = find_col(['new', 'អំណានថ្មី', 'ថ្មី'])

            self.tree.delete(*self.tree.get_children())

            for _, row in df.iterrows():
                val_code = str(row[c_code]).split('.')[0].zfill(6) if c_code else ""
                val_name = str(row[c_name]) if c_name else ""
                val_box = str(row[c_box]) if c_box else ""
                val_meter = str(row[c_meter]) if c_meter else ""
                val_old = str(row[c_old]) if c_old else "0"
                val_new = str(row[c_new]) if c_new else ""
                val_multiplier = "1"

                val_total = ""
                if val_new.strip():
                    n = clean_num(val_new)
                    o = clean_num(val_old)
                    m = clean_num(val_multiplier)
                    if n >= o:
                        val_total = f"{(n - o) * m:g}"

                vals = ("☐", val_code, val_name, val_box, val_meter, val_old, val_new, val_multiplier, val_total)
                self.tree.insert("", "end", values=vals)

            self.auto_recover_status()
            messagebox.showinfo("ជោគជ័យ", "បានទាញទិន្នន័យពី Database រួចរាល់!", parent=self)

        except Exception as e:
            messagebox.showerror("Error", f"ការទាញទិន្នន័យមានបញ្ហា:\n{e}")

    def import_excel(self):
        path = filedialog.askopenfilename(filetypes=[("Excel Files", "*.xlsx *.xls")])
        self.default_area = "គ្មានតំបន់"
        if not path:
            return

        try:
            df_raw = pd.read_excel(path, header=None).fillna('')
            self.tree.delete(*self.tree.get_children())
            self.areas_list = {}
            active_area = "គ្មានតំបន់"

            for _, row in df_raw.iterrows():
                row_str = [str(x).strip() for x in row.values]
                combined = " ".join(row_str)

                if "តំបន់" in combined:
                    for cell in row_str:
                        if "តំបន់" in cell:
                            active_area = cell.replace("៖", ":").replace("  ", " ").strip()
                            if active_area not in self.areas_list:
                                self.areas_list[active_area] = []
                            break
                    continue

                try:
                    code_cell = str(row.iloc[1]).strip() if len(row) > 1 else ""
                    if code_cell and code_cell.replace('.', '', 1).replace('-', '').isdigit():
                        vals = (
                            "☐",
                            str(row.iloc[1]).split('.')[0].zfill(6),
                            str(row.iloc[2]),
                            str(row.iloc[4]) if len(row) > 4 else "",
                            str(row.iloc[6]) if len(row) > 6 else "",
                            str(row.iloc[7]) if len(row) > 7 else "0",
                            str(row.iloc[8]) if len(row) > 8 else "",
                            str(row.iloc[9]) if len(row) > 9 else "1",
                            ""
                        )

                        self.areas_list.setdefault(active_area, []).append(vals)
                        self.tree.insert("", "end", values=vals)
                except Exception:
                    continue

            self.auto_recover_status()
            total = len(self.tree.get_children())
            messagebox.showinfo("ជោគជ័យ", f"បានទាញទិន្នន័យចូល Treeview រួចរាល់!\nសរុប {total} ជួរ", parent=self)

        except Exception as e:
            messagebox.showerror("Error", f"មានបញ្ហាក្នុងការទាញ Excel:\n{str(e)}", parent=self)

    def import_pdf(self):
        path = filedialog.askopenfilename(filetypes=[("PDF", "*.pdf")])
        if path:
            try:
                with pdfplumber.open(path) as pdf:
                    for page in pdf.pages:
                        table = page.extract_table()
                        if table:
                            for row in table[1:]:
                                if row and len(row) > 2 and row[2]:
                                    code = re.sub(r'\D', '', str(row[2])).zfill(6)
                                    self.tree.insert("", "end", values=("☐", code, row[6] if len(row) > 6 else "0", "", "", "0", row[7] if len(row) > 7 else "", "1", ""))
                self.auto_recover_status()
            except Exception as e:
                messagebox.showerror("Error", f"PDF Error: {e}", parent=self)

    def start_automation(self):
        """ ចាប់ផ្ដើមបញ្ចូលស្វ័យប្រវត្តិ ដោយមានការរាប់ថយក្រោយសិន """
        items = [i for i in self.tree.get_children() if self.tree.item(i, 'values')[0] == "☑" and 'done' not in self.tree.item(i, 'tags')]
        if not items:
            messagebox.showwarning("Warning", "សូមជ្រើសរើសជួរដែលត្រូវបញ្ចូល!", parent=self)
            return

        threading.Thread(target=self.countdown_and_run, daemon=True).start()

    def countdown_and_run(self):
        """ មុខងាររាប់ថយក្រោយ ៨ វិនាទី មុននឹងបញ្ចូល """
        self.btn_run.configure(state="disabled")

        for i in range(8, 0, -1):
            self.btn_run.configure(text=f"⏳ រង់ចាំ {i}s...")
            try:
                winsound.Beep(600, 100)
            except Exception:
                pass
            time.sleep(1)

        self.btn_run.configure(text="🚀 កំពុងបញ្ចូល...", fg_color="#e67e22")
        self.is_running = True
        pyautogui.FAILSAFE = True
        try:
            keyboard.add_hotkey('esc', self.stop_automation)
        except Exception:
            pass

        self.work_logic()

    def stop_automation(self):
        """ បញ្ឈប់ការងារ និងប្តូររូបរាងប៊ូតុងមកដើមវិញ """
        self.is_running = False
        print("Automation Stopped!")
        try:
            keyboard.remove_all_hotkeys()
        except Exception:
            pass
        try:
            winsound.Beep(400, 500)
        except Exception:
            pass
        self.after(0, lambda: self.btn_run.configure(text="🚀 ចាប់ផ្តើមបញ្ចូល", fg_color="green", state="normal"))

    def work_logic(self):
        items = [i for i in self.tree.get_children() if self.tree.item(i, 'values')[0] == "☑" and 'done' not in self.tree.item(i, 'tags')]
        if not items:
            self.after(0, lambda: messagebox.showwarning("Warning", "សូមជ្រើសរើសជួរដែលត្រូវបញ្ចូល!", parent=self))
            return

        interval = self.speed_slider.get()
        for idx, item in enumerate(items):
            if not self.is_running:
                break

            vals = self.tree.item(item, 'values')

            # --- ០. ឆែកកូដអតិថិជនដែលមានអក្សរ ---
            code_val = str(vals[1]).strip()
            has_letter_code = bool(re.search(r'[a-zA-Z]', code_val))

            # --- ១. ឆែកលេខនាឡិកា (Meter) ---
            meter_val = str(vals[4]).strip().lower()
            is_empty_meter = meter_val in ["", "nan", "-", "none", "null", ".", "nan"]

            # --- ២. ឆែកអំណាន (បំប្លែង និងសម្អាតសញ្ញាក្បៀស) ---
            try:
                def clean_number(text):
                    if not text:
                        return None
                    cleaned = str(text).replace(',', '').strip()
                    if cleaned in ["", "nan", "-", "None"]:
                        return None
                    return float(cleaned)

                old_val = clean_number(vals[5])
                new_val = clean_number(vals[6])

                if old_val is None:
                    old_val = 0.0
                if new_val is None:
                    new_val = -1.0

            except Exception as e:
                print(f"Error parsing numbers for {vals[1]}: {e}")
                old_val = 0.0
                new_val = -1.0

            # --- លក្ខខណ្ឌត្រួតពិនិត្យ (Skip Logic) ---
            if has_letter_code or is_empty_meter or (new_val < old_val):
                if has_letter_code:
                    reason = f"កូដមានអក្សរ ({code_val})"
                elif is_empty_meter:
                    reason = "គ្មានលេខនាឡិកា"
                else:
                    reason = f"អំណានខុស (ថ្មី:{new_val} < ចាស់:{old_val})"

                print(f"🛑 រំលងកូដ {vals[1]}: {reason}")

                self.after(0, lambda i=item: self.tree.item(i, tags=('skipped',)))
                continue

            # --- ៣. ប្រសិនបើត្រឹមត្រូវ ទើបចាប់ផ្តើមបញ្ចូល ---
            self.after(0, lambda p=(idx + 1) / len(items): self.progress.set(p))

            if not self.dry_run:
                try:
                    # កិច្ចការទី១៖ បញ្ចូលកូដអតិថិជន
                    if not self.is_running:
                        break
                    try:
                        winsound.Beep(800, 100)
                    except Exception:
                        pass
                    self.write_text(str(vals[1]))
                    pyautogui.press('enter')

                    # រង់ចាំកម្មវិធី Billing ដំណើរការ
                    wait_time = 1.2 + interval
                    for _ in range(int(wait_time * 10)):
                        if not self.is_running:
                            return
                        time.sleep(0.1)

                    # កិច្ចការទី២៖ បញ្ចូលអំណានថ្មី
                    if not self.is_running:
                        break
                    input_new_val = str(vals[6]).replace(',', '').strip()
                    self.write_text(input_new_val)
                    pyautogui.press('enter')

                    # កត់ត្រាចូល SQLite និងដូរពណ៌ក្នុងតារាងជាពណ៌បៃតង
                    self.add_to_log(vals[1])
                    self.after(0, lambda i=item: [self.tree.item(i, tags=('done',)), self.update_stats()])

                    # រង់ចាំមុនបន្តទៅលេខកូដបន្ទាប់
                    wait_time_end = 0.8 + interval
                    for _ in range(int(wait_time_end * 10)):
                        if not self.is_running:
                            return
                        time.sleep(0.1)

                except pyautogui.FailSafeException:
                    self.stop_automation()
                    self.after(0, lambda: messagebox.showwarning("Failsafe", "Mouse កៀនអេក្រង់ - បញ្ឈប់!", parent=self))
                    return
            else:
                # ករណី Dry Run (សាកល្បងដោយមិនវាយបញ្ចូលពិតប្រាកដ)
                time.sleep(0.5)
                self.after(0, lambda i=item: [self.tree.item(i, tags=('done',)), self.update_stats()])

        # បញ្ចប់ការងារ
        self.stop_automation()
        self.after(0, lambda: messagebox.showinfo("Done", "ប្រតិបត្តិការបានបញ្ចប់!", parent=self))


class AppLauncher(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("⚡ E-POWER Billing Auto-Sync & Automation Pro")
        self.geometry("1100x720")
        self.minsize(960, 600)

        ctk.set_appearance_mode("System")
        ctk.set_default_color_theme("blue")

        self.main_frame = UXAutoInputFinal(self)
        self.main_frame.pack(fill="both", expand=True)


if __name__ == "__main__":
    app = AppLauncher()
    app.mainloop()
