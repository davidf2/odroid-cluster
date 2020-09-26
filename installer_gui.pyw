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

FIELD_PADDING_X=100
FIELD_PADDING_Y=30
FIELD_PADDING=100
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
	window.f1=Frame(window, background=BACKGROUND_COLOR)
	window.f2=Frame(window, background=BACKGROUND_COLOR)
	window.f3=Frame(window, background=BACKGROUND_COLOR)
	# Añadirlas al panel con su respectivo texto.
	window.notebook.add(window.f1, text="Install")
	window.notebook.add(window.f2, text="Advanced")
	window.notebook.add(window.f3, text="Slurm")
	
def add_formtext(frame_parent, label_text, default_text, input_width):
	frame=Frame(frame_parent, background=BACKGROUND_COLOR)
	frame_left=Frame(frame, background=BACKGROUND_COLOR)
	frame_right=Frame(frame, background=BACKGROUND_COLOR)
	label = Label(frame_left, text = label_text,background=BACKGROUND_COLOR,font=(0,FONT_SICE))
	text_input = Text(frame_right, height=1, width=input_width,font=(0,FONT_SICE))
	text_input.insert(INSERT, default_text)
	label.pack(side=RIGHT)
	text_input.pack(side=LEFT)
	frame.pack(side=TOP,fill=X, padx=FIELD_PADDING_X, pady=FIELD_PADDING_Y)
	frame_left.pack(side=LEFT, fill=X)
	frame_right.pack(side=LEFT,padx=FIELD_PADDING, fill=X)
	return(text_input)
	

def add_content_install(window):
	text_name=add_formtext(window.f1, "Name:", "odroid", 20);
	text_name=add_formtext(window.f1, "Default password:", "odroid", 20);
	

def installer_screen(window):
	#Destruim la finestra
	window.destroy()
	window = Tk()
	# Modifiquem el color de fons
	window.configure(background=BACKGROUND_COLOR)
	
	# Afegim els estils per a la barra de menú
	style = ttk.Style()
	settings = {"TNotebook.Tab": {"configure": {"padding": [80, 10],
												"background": "#231f20",
												"foreground": "#ffffff",
												"font" : (FONT, '15')
											   },
								  "map": {"background": [("selected", MAIN_COLOR), 
														 ("active", "#AA554F")]

										 }
								  }
			   }
	
	style.configure('TCheckbutton', focuscolor=style.configure(".")["background"])

	style.theme_create("mi_estilo", parent="alt", settings=settings)
	style.theme_use("mi_estilo")

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
	

# Creem la finestra principal
root = Tk()
# Carrega la finestra de benvinguda
load_screen(root)
# Al cap de 1,5 segons carreguem el l'instalador
root.after(1500, lambda: installer_screen(root)) 

root.mainloop() 


