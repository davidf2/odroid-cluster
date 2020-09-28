#!/usr/bin/python3

from tkinter import ttk
from tkinter import *  
from PIL import ImageTk,Image,ImageOps
import time
from fontTools.ttLib import TTFont
from pathlib import Path

font = TTFont('optima-roman.ttf')
font.save(str(Path.home())+"/.local/share/fonts/optima-roman.ttf")

MAIN_COLOR='#90292A'
BACKGROUND_COLOR='#fafafa'
FONT="Optima"
TEXT_FONT=0

FIELD_PADDING_X=100
FIELD_PADDING_Y=30
FRAME_PADDING_X=100
FRAME_PADDING_Y=80
FONT_SICE=15

def centerwindow(window):
	
	# Agafem l'amplada i alçada de
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
	layer.image = photo # keep a reference!
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

	centerwindow(window)

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
	
	frame1 = Frame(window.f1, background=BACKGROUND_COLOR)
	frame1.row=0
	frame2 = Frame(window.f1, background=BACKGROUND_COLOR)
	frame1.var1 = IntVar()
	frame1.var1.set(0)
	frame1.var2 = IntVar()
	frame1.var2.set(0)
	text_password = Text()
	label_password = Label()
	
	
	add_label(frame1, "Name of OS user:")
	text_name = add_formtext(frame1, "odroid", 20)
	
	add_label(frame1, "Hostname assigned to nodes:")
	text_hostname = add_formtext(frame1, "odroid", 20)
	
	add_label(frame1, "Security level:")
	add_radiobutton(frame1, "0 - Use default password", frame1.var1, 0, lambda: grid_objects({text_password, label_password}))
	add_radiobutton(frame1, "1 - Type password", frame1.var1, 1, lambda: ungrid_objects({text_password, label_password}))
	
	label_password=add_label(frame1, "Default OS user password:")
	text_password = add_formtext(frame1, "odroid", 20)
	add_label(frame1, "Maximum number of nodes:")
	text_num_nodes=add_formtext(frame1, "255", 20)
	add_checkbutton(frame1, "Upgrade nodes",frame1.var2)
	
	
	button=ttk.Button(frame2,text='INSTALL NOW', command=0)
	
	frame2.pack()
	button.pack()
	frame2.pack(side=BOTTOM)
	frame1.pack(side=TOP, fill=X)
	
def add_content_advanced(window):
	window.f2.row=0
	add_label(window.f2, "Upstream DNS server 1:")
	dns1=add_ip(window.f2, ["8","8","8","8"])
	add_label(window.f2, "Upstream DNS server 2:")
	dns2=add_ip(window.f2, ["8","8","4","4"])
	add_label(window.f2, "Scripts directory")
	scripts_dir=add_formtext(window.f2,"/opt/scripts",20)
	add_label(window.f2, "Slurm directory")
	scripts_dir=add_formtext(window.f2,"/usr/local/slurm",20)
	
	
def installer_screen(window):
	#Destruim la finestra
	window.destroy()
	window = Tk()
	# Modifiquem el color de fons
	window.configure(background=BACKGROUND_COLOR)
	
	# Afegim els estils per a la barra de menú
	style = ttk.Style()
	
	
	style.theme_settings("default",	{
									"TNotebook.Tab": {"configure": {"padding": [80, 10],
														"background": "#231f20",
														"foreground": "white",
														"font" : (FONT, FONT_SICE)
													   },
												"map": {"background": [("selected", MAIN_COLOR), 
																	 ("active", "#AA554F")]

														}
													},
									"TButton": {"configure": {		"padding": [50, 15],
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
													}
									})
				

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

# Creem la finestra principal
root = Tk()
# Carrega la finestra de benvinguda
load_screen(root)
# Al cap de 1,5 segons carreguem el l'instalador
root.after(1500, lambda: installer_screen(root)) 

root.mainloop() 


