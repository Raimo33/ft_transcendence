documentare la scelta di hashed index di 'created_at' + keyset pagination cosi' la chiave fornita viene paragonata all'index in O(1)
fare l'analisi della time complexity di ogni cosa, ad esempio in questo caso O(1 + k)

spiegare come mai il refresh delle materialized view viene fatto in specifici intervalli:
 se viene fatto ad ogni inserimento succede che le queries si possono perdere determinati valori o ripetere piu valori siccome i match possono solo aumentare

spiegare motivo delle partition e perche' in user non vengono usate, ecc