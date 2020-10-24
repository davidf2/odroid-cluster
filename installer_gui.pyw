#!/usr/bin/python3
# -*- coding: utf-8 -*-

from tkinter import ttk
from tkinter import *  
from PIL import ImageTk,Image
import time
from fontTools.ttLib import TTFont
from pathlib import Path
from tkinter import messagebox
from cypherAES import CypherAES
import subprocess
import tkinter.font as tkFont
import re
from icu import Locale

font = TTFont('optima-roman.ttf')
font.save(str(Path.home())+"/.local/share/fonts/optima-roman.ttf")

OPTIONS_FILE="odroid_cluster.conf"

MAIN_COLOR='#90292A'
BACKGROUND_COLOR='#fafafa'
FONT="Optima"
TEXT_FONT=0

FIELD_PADDING_X=100
FIELD_PADDING_Y=30
FRAME_PADDING_X=100
FRAME_PADDING_Y=80
FONT_SICE=15

options=("DEFAULT_USER", "DEFAULT_PASSWORD", "HOSTS_NAME", "MAX_NODES",
	"EXTERNALDNS1", "EXTERNALDNS2", "SCRIPTS_DIR", "UPGRADE", "SLURM_DIR",
	"IP_CLASS", "MAX_TIME")

theme= {
		"TNotebook.Tab": {"configure": {"padding": [80, 10],
							"background": "#231f20",
							"foreground": "white",
							"font" : (FONT, FONT_SICE)
						   },
					"map": {"background": [("selected", MAIN_COLOR), 
										 ("active", "#AA554F")]

							}
						},
		"TButton": {"configure": {		"padding": [30, 10],
										"background": MAIN_COLOR,
										"foreground": "white",
										"font" : (FONT, FONT_SICE)
									   },
					"map": {"background": [("selected", MAIN_COLOR), 
											 ("active", "#AA554F")]

							}
					},
		"TRadiobutton": {"configure": {	"padding": [0,10],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						  "map": {"background": [("selected", BACKGROUND_COLOR), 
												 ("active", BACKGROUND_COLOR)]

								 }
						},
		"TCheckbutton": {"configure": {	"padding": [0,20],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						  "map": {"background": [("selected", BACKGROUND_COLOR), 
												 ("active", BACKGROUND_COLOR)]

								 }
						},
		"TEntry": {"configure": {	"padding": [10,5],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						},
		"TLabel": {"configure": {	"padding": [10,5],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						},
		"TCombobox": {"configure": {		"padding": [10, 5],
										"background": BACKGROUND_COLOR,
										"font" : (FONT, FONT_SICE),
										'selectbackground': 0,
										'selectforeground': 'black'
									   },
						"map": {"background": [("selected", BACKGROUND_COLOR), 
												 ("active", BACKGROUND_COLOR),
												 ('readonly', BACKGROUND_COLOR)],
								"fieldbackground" : [('readonly','white')]
								 }
					},
		"TEntry": {"configure": {		"padding": [10, 5],
										"background": BACKGROUND_COLOR,
										"font" : (FONT, FONT_SICE)
									   }
					}
		}

def get_timezones():
	global timezones
	p = subprocess.run(['timedatectl', 'list-timezones'], universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	#p.stderr
	timezones = list(p.stdout.split("\n"))
	

def get_languages():
	global icu
	global languages
	icu = []
	languages = []
	#cat /usr/share/i18n/SUPPORTED | grep UTF-8 | grep -v @ | awk '{print $1}' | cut -d. -f1
	p = subprocess.run(['cat', '/usr/share/i18n/SUPPORTED'], universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	aux = list(p.stdout.split("\n"))
	# Seleccionem els country code
	for lang in aux:
		if(re.search(r'UTF-8', lang)):
			if(re.search(r'@', lang) is None):
				lang=lang.split()[0]
				icu.append(lang.split('.')[0])
				languages.append(Locale(lang).getDisplayName())

def get_pos_list(element, elements):
	line = 0
	counter=0
	for i in elements:
		if(element == i):
			line = counter
		counter += 1
	return(line)
	
def add_dropdown(window, elements, variable, text):
	
	frame = Frame(window, background=BACKGROUND_COLOR)
	
	label=ttk.Label(frame, text=text)
	position = get_pos_list(variable.get(), elements)
	combo = ttk.Combobox(frame, state="readonly", textvariable=variable, values=elements)
	
	combo.config(font=tkFont.Font(family=TEXT_FONT,size=FONT_SICE))
	if(position >= 0):
		combo.current(position)
	label.pack(expand=True, fill=X, side=LEFT, anchor=NW)
	combo.pack(expand=True, fill=X, side=LEFT, anchor=NW)
	frame.pack(expand=True, fill=BOTH)
	
	return(variable)
	
def start(window, password):
	res=check_password(password)
	if(res == 0):
		window.destroy()
		subprocess.call("x-terminal-emulator -e 'echo \""+password+"\" | sudo -Sk "+str(Path().absolute())+"/init_master.sh'", shell=True)
	else:
		password=""
		window.entry.delete(0,END)
		window.geometry("400x280")
		center_window(window)
		window.error_text.set("Wrong password!")


def check_password(password):
	res=subprocess.run("echo \""+password+"\" | sudo -Sk echo \"correct password\" 2> /dev/null", shell=True).returncode
	return(res)

def askPassword(window): 
	password = StringVar()
	pass_window = Toplevel(window)
	pass_window.error_text = StringVar()
	
	# Modifiquem el color de fons, titol i tamany
	pass_window.configure(background=BACKGROUND_COLOR)
	pass_window.title("")
	pass_window.geometry("400x250")
	center_window(pass_window)
	
	ttk.Label(pass_window, text="Enter your password").pack(pady=20)
	pass_window.entry=ttk.Entry(pass_window, textvariable=password, show="*")
	pass_window.entry.pack(pady=20)
	ttk.Button(pass_window, text="Start", command= lambda: start(pass_window, password.get())).pack(pady=20, side=BOTTOM)
	ttk.Label(pass_window, textvariable=pass_window.error_text, foreground="red").pack()

   
def read_option(option):
	f = open(OPTIONS_FILE, "r")
	found=None
	
	for line in f:
		splited=line.split("=")
		if(splited[0]==option):
			found=splited[1]
	f.close()
	
	return(found.rstrip())

def write_option(option, value):
	f = open(OPTIONS_FILE, "r")
	found=False
	
	lines = f.readlines()
	num_lines=len(lines)
	
	i=0
	while(found==False and i<num_lines):
		if(lines[i].split("=")[0]==option):
			found=True
			lines[i]=option+"="+value
		i+=1
	f.close()
	
	f = open(OPTIONS_FILE, "w")
	
	for line in lines:
		f.write(line.rstrip()+"\n")
	f.close()
	
	return(found)

def iplist_to_ipstring(list1):
	ip= ""
		
	for i in list1:
		ip+=i.get("1.0",END).rstrip()
		ip+="."
	
	return(ip[:-1])

def check_ip(list1, title_error):
	
	for i in list1:
		i=i.get("1.0",END)
		try:
			int(i)
		except ValueError:
			messagebox.showerror(message='The IP can only contain digits', title=title_error)
			return False
		if(int(i) < 0 or int(i) > 255):
			messagebox.showerror(message='The digits of the IP can only be between 0 and 255', title=title_error)
			return False
	return True
	
def center_window(window):
	# Agafem l'amplada i alçada de la pantalla
	window_width = window.winfo_reqwidth()
	window_height = window.winfo_reqheight()
	
	# Calculem la posició central agafant lamplada i alçada de la pantalla
	position_x = int(window.winfo_screenwidth()/2 - window_width/2)
	position_y = int(window.winfo_screenheight()/2 - window_height/2)
	
	
	# Canviem la posició de la finestra
	window.geometry("+%d+%d" % (position_x, position_y))

def add_image(container,scale, path):
	image = Image.open(path)

	width, height = image.size

	image=image.resize((int(width*scale), int(height*scale)))

	photo = ImageTk.PhotoImage(image)


	layer = Label(container,image=photo , background=MAIN_COLOR)
	layer.image = photo
	return(layer)

def load_screen(window):
	# Treiem la barra superior
	window.overrideredirect(1)

	screen_width=window.winfo_screenwidth()
	screen_height=window.winfo_screenheight()

	window.configure(bg=MAIN_COLOR)

	f1=Frame(window, background=MAIN_COLOR)

	l1=add_image(f1,0.5,"odroid_cluster.png")
	l3=add_image(f1,0.2,"urv.png")

	var = StringVar()
	l2 = Label(f1, textvariable = var, background=MAIN_COLOR, fg="white",font=(FONT,30))
	var.set("Odroid Cluster")

	l1.pack(padx=40, pady=10)
	l2.pack(padx=10, pady=20)
	l3.pack(side=RIGHT)
	f1.pack(padx=70, pady=30 )


	# Apparently a common hack to get the window size. Temporarily hide the
	# window to avoid update_idletasks() drawing the window in the wrong
	# position.
	root.withdraw()
	root.update_idletasks()  # Update "requested size" from geometry manager

	center_window(window)

	# This seems to draw the window frame immediately, so only call deiconify()
	# after setting correct window position
	window.deiconify()


def add_menu(window):
	window.notebook = ttk.Notebook(window)
	window.f1=Frame(window, background=BACKGROUND_COLOR, padx=FRAME_PADDING_X, pady=FRAME_PADDING_Y)
	window.f2=Frame(window, background=BACKGROUND_COLOR, padx=FRAME_PADDING_X, pady=FRAME_PADDING_Y)
	window.f3=Frame(window, background=BACKGROUND_COLOR, padx=FRAME_PADDING_X, pady=FRAME_PADDING_Y)
	# Añadirlas al panel con su respectivo texto.
	window.notebook.add(window.f1, text="Install")
	window.notebook.add(window.f2, text="Advanced")
	window.notebook.add(window.f3, text="Slurm")

def add_label(frame, text):
	label = Label(frame, text = text,background=BACKGROUND_COLOR,font=(TEXT_FONT,FONT_SICE))
	label.grid(row=frame.row, column=0, sticky=W, padx=FIELD_PADDING_X, pady=FIELD_PADDING_Y)
	return(label)
	
def add_formtext(frame, default_text, input_width):
	text_input = Text(frame, height=1, width=input_width,font=(TEXT_FONT,FONT_SICE))
	text_input.insert(INSERT, default_text)
	text_input.grid(row=frame.row, column=1, sticky=W, padx=FIELD_PADDING_X, pady=FIELD_PADDING_Y)
	
	frame.row=frame.row+1
	return(text_input)

def add_radiobutton(frame, text, var, val, command):
	radio_button = ttk.Radiobutton(frame, text=text, variable=var, value=val, command=command)
	radio_button.grid(row=frame.row, column=1, sticky=W, padx=FIELD_PADDING_X)
	frame.row=frame.row+1
	return(radio_button)

def add_checkbutton(frame, text, var):
	check_button = ttk.Checkbutton(frame, text=text, variable=var, compound=LEFT)
	check_button.grid(row=frame.row, column=0, sticky=W, padx=FIELD_PADDING_X)
	frame.row=frame.row+1
	return(check_button)

def add_ip(frame, default_ip):
	ip = []
	
	subframe = Frame(frame)
	
	for i in range(4):
		ip.append(Text(subframe, height=1, width=3,font=(TEXT_FONT,FONT_SICE)))
	
	c=0
	for i in ip:
		i.pack(side=LEFT)
		if(c < len(ip)-1):
			Label(subframe, text = ".",background=BACKGROUND_COLOR,font=(TEXT_FONT,FONT_SICE)).pack(side=LEFT)
		i.insert(INSERT,default_ip[c])
		c+=1
	
	subframe.grid(row=frame.row, column=1, sticky=W, padx=FIELD_PADDING_X)

	frame.row=frame.row+1
	return(ip)
	
def grid_objects(element):
	for e in element:
		e.grid()
	
def ungrid_objects(element):
	for e in element:
		e.grid_remove()

def check_if_grid(element):
	if(not element.grid_info()):
		return(True)
	else:
		return(False)

def add_content_install(window):
	window.f1.timezone = StringVar(window)
	window.f1.timezone.set(read_option("SYS_TIMEZONE"))
	window.f1.locale = StringVar(window)
	window.f1.locale.set(languages[get_pos_list(read_option("SYS_LANGUAGE"),icu)])
	frame1 = Frame(window.f1, background=BACKGROUND_COLOR)
	frame2 = Frame(window.f1, background=BACKGROUND_COLOR)
	
	
	frame1.row=0
	
	add_dropdown(window.f1, timezones, window.f1.timezone, "Time zone:")
	add_dropdown(window.f1, languages, window.f1.locale, "Language:")
	
	add_label(frame1, "Name of OS user:")
	window.f1.text_name = add_formtext(frame1, read_option("DEFAULT_USER"), 20)
	
	add_label(frame1, "Default hostname:")
	window.f1.text_hostname = add_formtext(frame1, read_option("HOSTS_NAME"), 20)
	
	button=ttk.Button(frame2,text='INSTALL NOW',  command = lambda: start_installation(window))

	button.pack()
	frame2.pack(side=BOTTOM)
	frame1.pack(side=TOP, fill=X)

def add_ip_a(frame):
	field2=StringVar()
	field3=StringVar()
	field4=StringVar()
	
def add_content_advanced(window):
	window.f2.row=0
	window.f2.radio1 = StringVar()
	window.f2.check1 = IntVar()
	window.f2.radio1.set(read_option("IP_CLASS"))
	window.f2.check1.set(read_option("UPGRADE"))
	text_password = Text()
	label_password = Label()
	
	add_label(window.f2, "Upstream DNS server 1:")
	splited_dns1=read_option("EXTERNALDNS1").split(".")
	window.f2.dns1=add_ip(window.f2, [splited_dns1[0],splited_dns1[1],splited_dns1[2],splited_dns1[3]])
	add_label(window.f2, "Upstream DNS server 2:")
	splited_dns2=read_option("EXTERNALDNS2").split(".")
	window.f2.dns2=add_ip(window.f2, [splited_dns2[0],splited_dns2[1],splited_dns2[2],splited_dns2[3]])
	add_label(window.f2, "Scripts directory")
	window.f2.scripts_dir=add_formtext(window.f2,read_option("SCRIPTS_DIR"),20)
	
	label=add_label(window.f2, "Private IP:")
	# Treiem el pady que afegeix l'etiqueta
	label.grid(pady=0) 
	add_radiobutton(window.f2, "Class A", window.f2.radio1, 'A', command=None)
	add_ip_a(window.f2)
	add_radiobutton(window.f2, "Class B", window.f2.radio1, 'B', command=None)
	add_radiobutton(window.f2, "Class C", window.f2.radio1, 'C', command=None)
	add_checkbutton(window.f2, "Upgrade nodes and master",window.f2.check1)
	
	label_password=add_label(window.f2, "Default OS user password:")
	text_password = add_formtext(window.f2, read_option("DEFAULT_PASSWORD"), 20)
	window.f2.text_password2 = text_password
	
def installer_screen(window):
	#Destruim la finestra
	window.destroy()
	window = Tk()
	# Modifiquem el color de fons
	window.configure(background=BACKGROUND_COLOR)
	
	# Afegim els estils per a la barra de menú
	style = ttk.Style()								
	style.theme_settings("default",	theme)
	
	# Configurar la font del ttk Combobox, la part desplegable
	window.option_add('*TCombobox*Listbox.font', tkFont.Font(family=TEXT_FONT,size=FONT_SICE))
	
	# Afegim una icona
	icon = PhotoImage(file='odroid_cluster_icon.png')
	window.tk.call('wm', 'iconphoto', window._w, icon)
	
	# Maximitzem la finestra
	window.geometry("%dx%d+0+0" % (window.winfo_screenwidth(), window.winfo_screenheight()))
	# Afegim el text de dalt
	window.winfo_toplevel().title("Odroid Cluster")
	add_menu(window)
	window.notebook.pack(expand=1, fill=BOTH)
	add_content_install(window)
	add_content_advanced(window)

def write_options(window):
	
	correct=True
	
	#try:
	#	int(window.f1.text_num_nodes.get("1.0",END))
	#except ValueError:
	#	messagebox.showerror(message='The number of nodes must be a digit.', title="Maximum number of nodes")
	#	correct=False
	#if(int(window.f1.text_num_nodes.get("1.0",END)) < 1):
	#	messagebox.showerror(message='At least there must be one node.', title="Maximum number of nodes")
	#	correct=False
	
	if(correct):
		correct = check_ip(window.f2.dns1, "DNS1")
	if(correct):
		correct = check_ip(window.f2.dns2, "DNS2")
	
	if(correct):
		write_option("DEFAULT_USER",window.f1.text_name.get("1.0",END))
		write_option("DEFAULT_PASSWORD",window.f1.text_password2.get("1.0",END))
		write_option("HOSTS_NAME",window.f1.text_hostname.get("1.0",END))
		write_option("EXTERNALDNS1",iplist_to_ipstring(window.f2.dns1))
		write_option("EXTERNALDNS2",iplist_to_ipstring(window.f2.dns2))
		write_option("SCRIPTS_DIR",window.f2.scripts_dir.get("1.0",END))
		write_option("UPGRADE",str(window.f2.check1.get()))
		write_option("IP_CLASS",str(window.f2.radio1.get()))
		write_option("SYS_TIMEZONE",str(window.f1.timezone.get()))
		write_option("SYS_LANGUAGE",str(icu[get_pos_list(window.f1.locale.get(),languages)]))
	return correct
	
def start_installation(window):
	correct=write_options(window)
	if(correct):
		password=askPassword(window)

# Creem la finestra principal
root = Tk()

get_timezones()
get_languages()

# Carrega la finestra de benvinguda
load_screen(root)
# Al cap de 1,5 segons carreguem el l'instalador
root.after(1500, lambda: installer_screen(root))
	
root.mainloop() 


