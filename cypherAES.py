from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
from Crypto.Random import get_random_bytes
from base64 import b64encode, b64decode
import json

class CypherAES:
	def __init__(self):
		self.key = get_random_bytes(16)
		
	def encrypt(self, data):
		data=data.encode('utf8')
		cipher = AES.new(self.key, AES.MODE_CBC)
		ct_bytes = cipher.encrypt(pad(data, AES.block_size))
		iv = b64encode(cipher.iv).decode('utf-8')
		ciphertext = b64encode(ct_bytes).decode('utf-8')
		result = json.dumps({'iv':iv, 'ciphertext':ciphertext})
		
		return result
		
	def decrypt(self, json_input):
		try:
			b64 = json.loads(json_input)
			iv = b64decode(b64['iv'])
			ct = b64decode(b64['ciphertext'])
			cipher = AES.new(self.key, AES.MODE_CBC, iv)
			pt = unpad(cipher.decrypt(ct), AES.block_size)
			return(pt.decode('utf8'))
		except (ValueError, KeyError):
			return None

