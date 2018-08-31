#!/usr/bin/python
#!/share/apps/Python/Python-2.7.1/bin/python


import os
import MySQLdb
import time
import thread

def nomNoeudsUnique(listeNoeuds):
    listetmp = listeNoeuds.split('+')
    listeFinale = []
    for noeud in listetmp:
        nomNoeud = noeud.split('/')[0]
        if nomNoeud not in listeFinale:
           listeFinale.append(nomNoeud)
    return listeFinale

def monitor_job(job_id, vide):
    #extraction du nom des noeuds pour une tache donnee
    nomNoeuds = nomNoeudsUnique(job_id[11])
    
    # remet les compteurs a 0 
    cptr={}
    nblecture=0
    nbnoeud=0
	
    for nom in nomNoeuds:
        #lance la commande pfmon sur chacun des noeuds
        fichier = open("/RQexec/ROOT/MONI/" + nom, 'r')
        compteurs = fichier.readlines()
        fichier.close()
	nbnoeud += 1

        if len(compteurs) > 0:
    	    for cmptrs in compteurs:
                if cmptrs[0] != '#' and cmptrs != '\n' and cmptrs[0] != '<':
                    data = cmptrs.split()
        	#somme des valeurs des compteurs provenant des differents noeuds
                    try:
                        if data[1] not in cptr:
                            cptr[data[1]] = float(data[0])
                        else:
                            cptr[data[1]] += float(data[0])
                        nblecture += 1
                    except:  #si il y a une chaine de caracteres imprevue
                        print "debut erreur"
                        print job_id
                        print data
                        print cmptrs
                        print compteurs
                        print "fin erreur"

    if nblecture > 0:
        cpi = cptr["UNHALTED_CORE_CYCLES"] / cptr["INSTRUCTIONS_RETIRED"]
        ipc = cptr["INSTRUCTIONS_RETIRED"] / cptr["UNHALTED_CORE_CYCLES"]
        pload = cptr["MEM_INST_RETIRED:LOADS"] / cptr["INSTRUCTIONS_RETIRED"] * 100
        pstore = cptr["MEM_INST_RETIRED:STORES"] / cptr["INSTRUCTIONS_RETIRED"] * 100
        pstall = cptr["RESOURCE_STALLS:ANY"] / cptr["UNHALTED_CORE_CYCLES"] * 100
        pbranch = cptr["BRANCH_INSTRUCTIONS_RETIRED"] / cptr["INSTRUCTIONS_RETIRED"] * 100
        if cptr["BRANCH_INSTRUCTIONS_RETIRED"] == 0:
            cptr["BRANCH_INSTRUCTIONS_RETIRED"] = 1
        mis_branch = cptr["MISPREDICTED_BRANCH_RETIRED"] / cptr["BRANCH_INSTRUCTIONS_RETIRED"] * 100
        l3_misses = cptr["LAST_LEVEL_CACHE_MISSES"] / cptr["LAST_LEVEL_CACHE_REFERENCES"] * 100
	sse_double = cptr["FP_COMP_OPS_EXE:SSE_DOUBLE_PRECISION"] / cptr["INSTRUCTIONS_RETIRED"] * 100
        sse_single = cptr["FP_COMP_OPS_EXE:SSE_SINGLE_PRECISION"] / cptr["INSTRUCTIONS_RETIRED"] * 100
        sse_int = cptr["FP_COMP_OPS_EXE:SSE2_INTEGER"] / cptr["INSTRUCTIONS_RETIRED"] * 100
        x87_instr = cptr["FP_COMP_OPS_EXE:X87"] / cptr["INSTRUCTIONS_RETIRED"] * 100
	temps = cptr["CPU_CLK_UNHALTED:THREAD_P"] / 3e9 / (12*nbnoeud)
	gflops = (2*cptr["FP_COMP_OPS_EXE:SSE_DOUBLE_PRECISION"]+4*cptr["FP_COMP_OPS_EXE:SSE_SINGLE_PRECISION"])/1e9/temps

  	#il faut mettre les requetes MySQL ici!!! :-)
        try:
            dconn = MySQLdb.connect(host="udem-stat.calculquebec.ca",user="CQadmin",passwd="xxxx",db="CQtaches")
            cursor = dconn.cursor()   
    
  	    cursor.execute("""
 	      INSERT INTO Tache_briaree (Job_ID,CPI,IPC,pload,pstore,pstall,pbranch,mis_branch,l3_misses,sse_double,sse_single,sse_int,x87_instr,gflops)
 	      VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) 
 	      """, (job_id[0].split('.')[0],cpi,ipc,pload,pstore,pstall,pbranch,mis_branch,l3_misses,sse_double,sse_single,sse_int,x87_instr,gflops))

  	    cursor.close()
  	    dconn.commit()
  	    dconn.close()
        except MySQLdb.Error:
            time.sleep(60)
	#print "jobid=",job_id[0].split('.')[0]
	#print "IPC=",ipc
	#print "pload=",pload
	#print "pstore=",pstore
	#print "pstall=",pstall
	#print "pbranch=",pbranch
	#print "mis_branch=",mis_branch
	#print "l3_misses=",l3_misses
	#print "sse_double=",sse_double
	#print "sse_single=",sse_single
	#print "sse_int=",sse_int
	#print "x87_instr=",x87_instr
	#print "mflops=",mflops
	#print " "
 
    
    	
while (1 == 1):   
   #leture des processus qui s'executent
   sortieQstat = os.popen("qstat -rn1t").readlines()

   #saute les 5 premieres lignes et decompose la sortie de qstat en liste 
   for sortie in sortieQstat[5:]:
       tache = sortie.split()
#       thread.start_new_thread(monitor_job,(tache,0))
       monitor_job(tache,0)

   # Dormir pendant deux minutes...
   time.sleep(120)

