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
		"TRadiobutton": {"configure": {	"padding": [0,5],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						  "map": {"background": [("selected", BACKGROUND_COLOR), 
												 ("active", BACKGROUND_COLOR)]

								 }
						},
		"TCheckbutton": {"configure": {	"padding": [0,5],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						  "map": {"background": [("selected", BACKGROUND_COLOR), 
												 ("active", BACKGROUND_COLOR)]

								 }
						},
		"TEntry": {"configure": {	"padding": [0,5],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						},
		"TLabel": {"configure": {	"padding": [0,5],
										"background": BACKGROUND_COLOR,
										"font" : (TEXT_FONT, FONT_SICE)
									   },
						},
		"TCombobox": {"configure": {		"padding": [0, 5],
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
		"TFrame": {"configure": {
								"background": BACKGROUND_COLOR
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

def ask_password(window): 
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
	f1.pack(padx=70, pady=30)


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
	window.f1=Frame(window, background=BACKGROUND_COLOR)
	window.f2=Frame(window, background=BACKGROUND_COLOR)
	window.f3=Frame(window, background=BACKGROUND_COLOR)
	# Añadirlas al panel con su respectivo texto.
	window.notebook.add(window.f1, text="Install")
	window.notebook.add(window.f2, text="Advanced")
	window.notebook.add(window.f3, text="Slurm")

def add_dropdown(window, elements, variable, text):
	
	frame = ttk.Frame(window)
	
	label=ttk.Label(frame, text=text)
	position = get_pos_list(variable.get(), elements)
	combo = ttk.Combobox(frame, state="readonly", textvariable=variable, values=elements)
	
	combo.config(font=(TEXT_FONT,FONT_SICE))
	if(position >= 0):
		combo.current(position)
	label.pack( fill=X, side=LEFT)
	combo.pack(fill=X, side=RIGHT)
	frame.pack(expand=True, fill=BOTH, side=TOP)
	
	return(variable)

def update_list(last, first, com, var):
	new_list=[]
	
	for i in range(int(first.get()),int(last)+1):
		new_list.append(str(i))
	com['values'] = new_list
	var.set(str(int(first.get())))
	
def add_ip_dropdown(window, elements, variable, combo2=None, variable2=None):
	position = get_pos_list(variable.get(), elements)
	combo = ttk.Combobox(window, state="readonly", textvariable=variable, values=elements, width=3)
	
	combo.config(font=(TEXT_FONT,FONT_SICE))
	if(position >= 0):
		combo.current(position)
	combo.pack(side=LEFT)
	if(combo2 != None and combo2 != None):
		combo.bind('<<ComboboxSelected>>', lambda last=elements[len(elements)-1], first=variable, com=combo2, var=variable2 : update_list(elements[len(elements)-1], first, com, var))
	
	return(combo)

def add_label(frame, text):
	label = ttk.Label(frame, text = text,background=BACKGROUND_COLOR,font=(TEXT_FONT,FONT_SICE))
	label.pack(side=LEFT)
	return(label)
	
def add_entry(window, default_text, label_text):
	frame = ttk.Frame(window)
	
	add_label(frame, label_text)
	entry = ttk.Entry(frame, font=(TEXT_FONT,FONT_SICE))
	entry.insert(INSERT, default_text)
	entry.pack(side=RIGHT)
	
	frame.pack(expand=True, fill=X)
	
	return(entry)

def add_radiobutton(window, text, var, val, command):
	radio_button = ttk.Radiobutton(window, text=text, variable=var, value=val, command=command)
	return(radio_button)
	
def add_radiobutton_group(window, label_text, var, text_list, options_list, commands=None):
	private_ip_frame = ttk.Frame(window)
	
	label=add_label(private_ip_frame, label_text)
	
	i2=0
	for i in text_list:
		add_radiobutton(private_ip_frame, i, var, options_list[i2], command=commands[i2]).pack(side=LEFT, expand=True,)
		i2+=1
	
	private_ip_frame.pack(expand=True, fill=X)
	
def add_checkbutton(window, text, var):
	frame = ttk.Frame(window)
	
	check_button = ttk.Checkbutton(frame, text=text, variable=var, compound=LEFT)
	check_button.pack(side=LEFT)
	frame.pack(expand=True, fill=X)
	return(check_button)

def add_ip(window, default_ip, text):
	ip = []
	
	frame = ttk.Frame(window)
	subframe = ttk.Frame(frame)
	
	label = add_label(frame, text)
	
	for i in range(4):
		ip.append(Text(subframe, height=1, width=3,font=(TEXT_FONT,FONT_SICE)))
	
	
	c=len(ip)-1
	for i in reversed(ip):
		i.pack(side=RIGHT)
		if(c > 0):
			Label(subframe, text = " .  ",background=BACKGROUND_COLOR,font=(TEXT_FONT,FONT_SICE)).pack(side=RIGHT)
		i.insert(INSERT,default_ip[c])
		c-=1
	subframe.pack(expand=True, fill=X)
	frame.pack(expand=True, fill=X)

	return(ip)

""" Funció per a resetejar els valors de les varaibles que formen el rang de IP privada A, a més 
	modifica els valors per defecte dels dos primers combobox que formen les dues IP, també modifica 
	els parametres de la funció que es crida al modificar el combobox del segon  nombre de la ip """
def set_ip_a():
	ip1.ip_num1.set(10)
	ip1.ip_num2.set(0)
	ip1.ip_num3.set(0)
	ip1.ip_num4.set(1)
	ip2.ip_num1.set(10)
	ip2.ip_num2.set(0)
	ip2.ip_num3.set(0)
	ip2.ip_num4.set(1)
	ip1.combo1['values'] = "10"
	ip2.combo1['values'] = "10"
	ip1.combo2['values'] = number_list
	ip2.combo2['values'] = number_list
	ip1.combo2.bind('<<ComboboxSelected>>', lambda last=number_list[len(number_list)-1], first=ip1.ip_num2, com=ip2.combo2, var=ip2.ip_num2 : update_list(number_list[len(number_list)-1], first, com, var))

""" Funció per a resetejar els valors de les varaibles que formen el rang de IP privada B, a més 
	modifica els valors per defecte dels dos primers combobox que formen les dues IP, també modifica 
	els parametres de la funció que es crida al modificar el combobox del segon  nombre de la ip """
def set_ip_b():
	elements=[]
	ip1.ip_num1.set(172)
	ip1.ip_num2.set(16)
	ip1.ip_num3.set(0)
	ip1.ip_num4.set(1)
	ip2.ip_num1.set(172)
	ip2.ip_num2.set(16)
	ip2.ip_num3.set(0)
	ip2.ip_num4.set(1)
	
	for i in range(16,32):
		elements.append(str(i))
		
	ip1.combo1['values'] = "172"
	ip2.combo1['values'] = "172"
	ip1.combo2['values'] = elements
	ip2.combo2['values'] = elements
	ip1.combo2.bind('<<ComboboxSelected>>', lambda last=elements[len(elements)-1], first=ip1.ip_num2, com=ip2.combo2, var=ip2.ip_num2 : update_list(elements[len(elements)-1], first, com, var))

""" Funció per a resetejar els valors de les varaibles que formen el rang de IP privada C, a més 
	modifica els valors per defecte dels dos primers combobox que formen les dues IP """
def set_ip_c():
	ip1.ip_num1.set(192)
	ip1.ip_num2.set(168)
	ip1.ip_num3.set(0)
	ip1.ip_num4.set(1)
	ip2.ip_num1.set(192)
	ip2.ip_num2.set(168)
	ip2.ip_num3.set(0)
	ip2.ip_num4.set(1)
	ip1.combo1['values'] = "192"
	ip2.combo1['values'] = "192"
	ip1.combo2['values'] = "168"
	ip2.combo2['values'] = "168"
	


""" Funció per afegir un 8 combobox per poder afegir el rang de ip 
	privada """
def add_private_ip(window, frame):
	# Declarem les variables necessaries com a globals
	global ip1, ip2
	global number_list
	ip1 = ttk.Frame(window);
	ip2 = ttk.Frame(window);
	
	ip1.ip_num1 = IntVar()
	ip1.ip_num2 = IntVar()
	ip1.ip_num3 = IntVar()
	ip1.ip_num4 = IntVar()
	
	ip2.ip_num1 = IntVar()
	ip2.ip_num2 = IntVar()
	ip2.ip_num3 = IntVar()
	ip2.ip_num4 = IntVar()
	
	number_list=[]
	number_list_end=[]
	

	for i in range(0,256):
		number_list.append(str(i))
		
	for i in range(1,255):
		number_list_end.append(str(i))
	
	subframe = ttk.Frame(frame)
	
	ip2.combo4=add_ip_dropdown(subframe, number_list_end, ip2.ip_num4)
	add_label(subframe, " . ").pack(side=RIGHT)
	ip2.combo3=add_ip_dropdown(subframe, number_list, ip2.ip_num3)
	add_label(subframe, " . ").pack(side=RIGHT)
	ip2.combo2=add_ip_dropdown(subframe, number_list, ip2.ip_num2)
	add_label(subframe, " . ").pack(side=RIGHT)
	ip2.combo1=add_ip_dropdown(subframe, ["0"], ip2.ip_num1)
	
	ip1.combo1=add_ip_dropdown(subframe, ["0"], ip1.ip_num1, ip2.combo1, ip2.ip_num1)
	add_label(subframe, " . ")
	ip1.combo2=add_ip_dropdown(subframe, number_list, ip1.ip_num2, ip2.combo1, ip2.ip_num2)
	add_label(subframe, " . ")
	ip1.combo3=add_ip_dropdown(subframe, number_list, ip1.ip_num3, ip2.combo3, ip2.ip_num3)
	add_label(subframe, " . ")
	ip1.combo4=add_ip_dropdown(subframe, number_list_end, ip1.ip_num4, ip2.combo4, ip2.ip_num4)
	
	if(window.f2.radio1.get() == 'C'):
		set_ip_c()
		
	elif(window.f2.radio1.get() == 'B'):
		set_ip_b()
		
	elif(window.f2.radio1.get() == 'A'):
		set_ip_a()
		
		
		
	ip2.combo1.pack(side=RIGHT)
	ip2.combo2.pack(side=RIGHT)
	ip2.combo3.pack(side=RIGHT)
	ip2.combo4.pack(side=RIGHT)
	
	subframe.pack(expand=True, fill=BOTH)



def add_content_install(window):
	padding_bottom = ttk.Frame(window.f1)
	padding_up = ttk.Frame(window.f1)
	content = ttk.Frame(window.f1)
	padding_left = ttk.Frame(window.f1)
	padding_right = ttk.Frame(window.f1)
	padding_right2 = ttk.Frame(window.f1)
	
	
	window.f1.timezone = StringVar()
	window.f1.timezone.set(read_option("SYS_TIMEZONE"))
	window.f1.locale = StringVar()
	window.f1.locale.set(languages[get_pos_list(read_option("SYS_LANGUAGE"),icu)])
	
	add_dropdown(content, timezones, window.f1.timezone, "Time zone:")
	add_dropdown(content, languages, window.f1.locale, "Language:")
	
	
	
	
	button=ttk.Button(padding_bottom,text='INSTALL NOW',  command = lambda: start_installation(window))
	
	padding_bottom.pack(fill=BOTH, side=BOTTOM)
	padding_left.pack(expand=True, side=LEFT)
	content.pack(expand=True, fill=BOTH, side=LEFT)
	padding_right.pack(expand=True, fill=BOTH, side=RIGHT)
	padding_right2.pack(expand=True, fill=BOTH, side=RIGHT)
	
	
	button.pack(expand=True, pady=20)


        
def add_content_advanced(window):
	window.f2.radio1 = StringVar()
	window.f2.check1 = IntVar()
	window.f2.radio1.set(read_option("IP_CLASS"))
	window.f2.check1.set(read_option("UPGRADE"))
	text_password = Text()
	
	padding_bottom = ttk.Frame(window.f2)
	padding_up = ttk.Frame(window.f2)
	content = ttk.Frame(window.f2)
	padding_left = ttk.Frame(window.f2)
	padding_right = ttk.Frame(window.f2)
	padding_right2 = ttk.Frame(window.f2)
	
	
	window.f2.text_name = add_entry(content, read_option("DEFAULT_USER"), "Default odroid user:")
	window.f2.text_hostname = add_entry(content, read_option("HOSTS_NAME"), "Default odroid hostname:")
	text_password = add_entry(content, read_option("DEFAULT_PASSWORD"), "Default odroid password:")
	window.f2.text_password2 = text_password
	
	splited_dns1=read_option("EXTERNALDNS1").split(".")
	window.f2.dns1=add_ip(content, [splited_dns1[0],splited_dns1[1],splited_dns1[2],splited_dns1[3]], "Upstream DNS server 1:")
	
	splited_dns2=read_option("EXTERNALDNS2").split(".")
	window.f2.dns2=add_ip(content, [splited_dns2[0],splited_dns2[1],splited_dns2[2],splited_dns2[3]], "Upstream DNS server 2:")
	
	window.f2.scripts_dir=add_entry(content,read_option("SCRIPTS_DIR"),"Scripts directory")
	
	add_checkbutton(content, "Upgrade nodes and master",window.f2.check1)
	
	add_radiobutton_group(content,"Private IP:",window.f2.radio1, ["Class A", "Class B", "Class C"], ['A', 'B', 'C'], [lambda :set_ip_a(), lambda :set_ip_b(), lambda :set_ip_c()])
	
	add_private_ip(window,content)
	
	padding_bottom.pack(fill=BOTH, side=BOTTOM)
	padding_left.pack(expand=True, side=LEFT)
	content.pack(expand=True, fill=BOTH, side=LEFT)
	padding_right.pack(expand=True, fill=BOTH, side=RIGHT)
	padding_right2.pack(expand=True, fill=BOTH, side=RIGHT)
	
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
		write_option("DEFAULT_USER",window.f2.text_name.get("1.0",END))
		write_option("DEFAULT_PASSWORD",window.f2.text_password2.get("1.0",END))
		write_option("HOSTS_NAME",window.f2.text_hostname.get("1.0",END))
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
		password=ask_password(window)

# Creem la finestra principal
root = Tk()

get_timezones()
get_languages()

# Carrega la finestra de benvinguda
load_screen(root)
# Al cap de 1,5 segons carreguem el l'instalador
root.after(1500, lambda: installer_screen(root))
	
root.mainloop() 


