#!/usr/bin/python3
# -*- coding: utf-8 -*- 


from tkinter import ttk
from tkinter import *
import subprocess


MAIN_COLOR='#90292A'
BACKGROUND_COLOR='#fafafa'
FONT="Optima"
TEXT_FONT=0

FIELD_PADDING_X=100
FIELD_PADDING_Y=30
FRAME_PADDING_X=100
FRAME_PADDING_Y=80
FONT_SICE=15

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
						}
		
		}



def center_window(window):
	# Agafem l'amplada i alçada de la pantalla
	window_width = window.winfo_reqwidth()
	window_height = window.winfo_reqheight()
	
	# Calculem la posició central agafant lamplada i alçada de la pantalla
	position_x = int(window.winfo_screenwidth()/2 - window_width/2)
	position_y = int(window.winfo_screenheight()/2 - window_height/2)
	
	
	# Canviem la posició de la finestra
	window.geometry("+%d+%d" % (position_x, position_y))

def start(window, password):
	res=check_password(password)
	if(res == 0):
		print(password)
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
	pass_window = window
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


# Creem la finestra principal
root = Tk()

# Afegim els estils per a la barra de menú
style = ttk.Style()								
style.theme_settings("default",	theme)
	
askPassword(root)
root.mainloop() 
