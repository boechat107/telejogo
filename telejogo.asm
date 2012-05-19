;+++++++++++++++++++++++++++++++++++++++++++
;+ Exercicio de Programacao - Micro I
;+
;+ Andre A. Boechat
;+ Clebson J. M. Oliveira
;+
;+ Dezembro de 2008
;+++++++++++++++++++++++++++++++++++++++++++

	segment	.text
	org	0100h

start:
	mov	ax,cs
	mov	ds,ax
	mov	ss,ax
	mov	sp,stacktop

; salvar condicao original da interrupcao int 9
	xor	ax,ax		;zera ax.
	mov	es,ax		;cada interrupcao possui 4 bytes de memoria.
	mov	ax,[es:int9*4]	;endereco da interrupcao.
	mov	[int9_orig],ax	;salva offset original.
	mov	ax,[es:int9*4+2]
	mov	[int9_orig+2],ax	;salva cs original

; mudar a rotina da interrupcao int 9
	cli
	mov	ax,intTeclado
	mov	[es:int9*4],ax
	mov	[es:int9*4+2],cs
	sti

; salva rotina original da interrupcao int 1Ch
	mov	ax,[es:int1Ch*4]
	mov	[int1Ch_orig],ax	;salva offset.
	mov	ax,[es:int1Ch*4+2]
	mov	[int1Ch_orig+2],ax	;salva segmento.

; muda rotina da interrupcao de tempo int 1Ch
	cli
	mov	ax,intTempo
	mov	[es:int1Ch*4],ax
	mov	[es:int1Ch*4+2],cs
	sti

; salvar modo de video atual
	mov	ah,0Fh
	int	10h
	mov	[video_ant],al

; altera o modo de video
	xor	ah,ah         ;Funcao 00h (int 10h)
	mov	al,03h        ;Modo de video = 03h (25l x 80c) 2bytes por pixel
	int	10h           ;Muda o modo de video

	xor	bh,bh
	mov	ah,01h
	mov	ch,20h	;Desaparece com a linha do cursor.
	int	10h
	
	mov	ax,seg_video  ;Coloca o segmento da memória_
	mov	es,ax         ;de video em AX.

; colore todo o campo
	call	colore_campo


;;;;;;;;;;;;;;;;;;;;;;;;;;;
; loop principal do jogo
;;;;;;;;;;;;;;;;;;;;;;;;;;;
main:

; verifica se o usuario deseja encerrar o jogo
	mov	al,[flag_jogo]
	test	al,1b	;bit da tecla ESC
	jnz	skipJmp		;truque para aumentar salto.
	jmp	main_fim
skipJmp:

;verifica se o usuario perdeu uma bola
	test	al,100000b
	jnz	main2	;pula se nao perdeu bola

	or	al,00101000b	;desabilita a raquete e a bola, e desabilita perda de bola.
	mov	[flag_jogo],al
	mov	al,[bolas_user]
	dec	al
	mov	[bolas_user],al	;atualiza a quantidade de bolas restantes.

	mov	dx,msg2
	call	print_string	;imprime mensagem.
	call	printchar_dec	;imprime quantidade de bolas restantes.

	;exibe a mensagem por um tempo.
	call	delay
	call	colore_campo		;apaga mensagem da tela.
	call	reinicia_bola		;reposiciona bola.
	xor	ah,ah
	mov	[cont_temp_bola],ah	;zera contador de tempo.
	call	descongela_jogo



; verifica se o usuario ainda tem bola p/ jogar
main2:
	mov	ah,[bolas_user]
	cmp	ah,0
	ja	pontuacao	;continua jogo se ainda existirem mais bolas.

	;se nao existirem mais bolas, parar jogo e avisar o usuario.
	mov	al,[flag_jogo]
	call	congela_jogo		;congela jogo.

	mov	dx,msg1
	call	print_string	;imprime mensagem


	;espera usuario se decidir
main5:
	mov	al,[flag_jogo]
	test	al,1b	;bit da tecla ESC.
	jz	main	;pula se apertar ESC e sai do jogo (evita esticar o pulo).
	mov	ah,[bolas_user]
	cmp	ah,0	;compara quantidade de bolas do usuario.
	je	main5	;pula pq usuario ainda nao se decidiu.

	xor	ah,ah
	mov	[pontuacao_user],ah	;zera pontuacao.
	mov	[nivel_jogo],ah		;zera nivel de dificuldade.


	;recomecar jogo no nivel zero
	call	reinicia_bola	;coloca a bola na posicao inicial.
	call	colore_campo	;colore toda a tela.
	
	xor	ah,ah
	mov	[cont_temp_bola],ah	;zera contador de tempo.

	mov	al,tam_raquete_ini
	mov	[tam_raquete],al	;tamanho original da raquete
	mov	bx,fim_video
	add	ax,ax
	sub	bx,ax
	mov	[rmax_pos],bx		;posicao maxima da raquete.

	mov	ax,raqPos_ini
	mov	[raqPos_atual],ax	;posicao inicial da raquete.

	mov	al,vel_bola_ini
	mov	[vel_bola],al		;velocidade original da bola.

	mov	al,tam_bola_ini
	mov	[tam_bola],al		;tamanho original da bola.
	mov	ah,colunas_video
	add	al,al
	sub	ah,al
	mov	[desloc_max_x],ah	;deslocamento maximo em x.

	mov	al,tam_bola_ini
	mov	ah,linhas_video/2
	dec	ah
	sub	ah,al
	mov	[desloc_max_y],ah	;deslocamento maximo em y.

	mov	al,Npassos_ini		;tamanho de passos em y originais.
	mov	[desloc_y],al
	add	al,al
	mov	[desloc_x],al		;tamanho de passos em x originais.

	mov	al,[flag_jogo]
	and	al,11100001b	;habilita movimento bola e raquete, muda placar.
	mov	[flag_jogo],al	;indica que bola e raquete se moveram.


; controle da pontuacao no jogo
pontuacao:
	xor	ax,ax
	mov	al,[cont_temp_plac]
	cmp	al,tempo_pont		;verifica se deu o tempo de pontuacao.
	jnb	skipJmp30		;truque p/ aumentar o pulo.	
	jmp	move_raquete;		pula se ainda nao marca ponto.
skipJmp30:

	xor	ax,ax
	mov	[cont_temp_plac],al	;zera tempo do placar.
	mov	al,[pontuacao_user]
	inc	al			;soma um ponto.
	mov	bl,10			;limita pontuacao maxima do jogo em 9.
	div	bl			;resultado correto em ah (resto div).
	mov	bl,[flag_jogo]
	and	bl,11101111b		;indica mudanca placar.
	mov	[flag_jogo],bl
	cmp	ah,0
	je	pontuacao1

	;ainda nao aumenta nivel de dificuldade.
	mov	[pontuacao_user],ah
	jmp	move_raquete

	;incrementa nivel de dificuldade
pontuacao1:
	mov	[pontuacao_user],ah	;zera placar.
	call	congela_jogo		;congela bola e raquete.

	mov	al,[nivel_jogo]
	inc	al
	mov	[nivel_jogo],al
	cmp	al,nivel_max
	jna	skipJmp40		;pula se chegou ao nivel maximo.
	jmp	pont_nmax
skipJmp40:

	mov	dx,msg3
	call	print_string		;imprime mensagem.
	call	printchar_dec		;imprime nivel do jogo.
	call	delay			;exibi mensagem por um tempo.

	;nivel 1
	mov	al,[nivel_jogo]
	cmp	al,1
	jne	pont_nivel2
	mov	al,vel_bola_ini/2
	mov	[vel_bola],al		;altera velocidade da bola pelo tempo.

	jmp	pont_fim
	

	;nivel 2
pont_nivel2:
	mov	al,[nivel_jogo]
	cmp	al,2
	jne	pont_nivel3
	mov	al,1
	mov	[vel_bola],al		;altera velocidade da bola pelo tempo.

	jmp	pont_fim
	

	;nivel 3
pont_nivel3:
	mov	al,[nivel_jogo]
	cmp	al,3
	jne	pont_nivel4

	mov	al,vel_bola_ini
	mov	[vel_bola],al		;diminui a velocidade por tempo. 
	mov	al,2
	mov	[tam_bola],al		;reduz tamanho da bola.

	mov	ah,colunas_video
	add	al,al
	sub	ah,al
	mov	[desloc_max_x],ah

	mov	ah,linhas_video/2-1
	mov	al,[tam_bola]
	sub	ah,al
	mov	[desloc_max_y],ah

	jmp	pont_fim

	;nivel 4
pont_nivel4:
	mov	al,[nivel_jogo]
	cmp	al,4
	jne	pont_nivel5
	mov	al,vel_bola_ini/2
	mov	[vel_bola],al		;altera velocidade da bola pelo tempo.

	jmp	pont_fim

	;nivel 5
pont_nivel5:
	mov	al,[nivel_jogo]
	cmp	al,5
	jne	pont_nivel6
	mov	al,1
	mov	[vel_bola],al		;altera velocidade da bola pelo tempo.

	jmp	pont_fim

	;nivel 6
pont_nivel6:
	mov	cl,tam_raquete_ini/2+2		
	mov	[tam_raquete],cl	;altera tamanho da raquete e sua posicao maxima
	add	cx,cx			;no video.
	mov	bx,fim_video
	sub	bx,cx
	mov	[rmax_pos],bx
	
	jmp	pont_fim
	
	;usuario conseguiu terminar o jogo.
pont_nmax:
	mov	dx,msg4
	call	print_string		;imprime mensagem.
	call	delay			;exibi mensagem por um tempo.
	xor	al,al
	mov	[bolas_user],al		;p/ iniciar nova partida


pont_fim:
	call	colore_campo
	call	reinicia_bola
	xor	ah,ah
	mov	[cont_temp_bola],ah	;zera contador de tempo.
	call	descongela_jogo



; move a raquete de acordo com a flag_raquete
move_raquete:
	;verifica se ja deu o tempo p/ movimentar a raquete.
	mov	al,[cont_temp_raq]
	cmp	al,temp_mov_raq
	jb	colore_raquete

	;verifica se moveu p/ esquerda
	mov	al,[flag_raquete]
	test	al,10b
	jz	move_raq20		;pula se nao moveu p/ esquerda.

	mov	ax,[raqPos_atual]	;recupera posicao da raquete.
	sub	ax,vel_mov	;velocidade de movimentacao.
	cmp	ax,rmin_pos	;verifica se a barra ultrapassa o limite a esquerda.
	jnb	move_raq10
	mov	ax,rmin_pos	;corrige posicao da raquete.
move_raq10:	
	mov	[raqPos_atual],ax	;atualiza posicao da raquete.
	mov	al,[flag_jogo]
	and	al,11111101b	;altera apenas o bit de movimentacao
	mov	[flag_jogo],al
	jmp	move_raqFim	

	;verifica se moveu p/ direita
move_raq20:
	mov	al,[flag_raquete]
	test	al,1b
	jz	move_raqFim		;pula se nao moveu p/ direita.

	mov	ax,[raqPos_atual]	;recupera posicao da raquete.
	add	ax,vel_mov	;velocidade de movimentacao.
	cmp	ax,[rmax_pos]	;verifica se ultrapassou limite de video.
	jb	move_raq30
	mov	ax,[rmax_pos]	;corrige posicao da raquete.
move_raq30:
	mov	[raqPos_atual],ax	;atualiza posicao da raquete.
	mov	al,[flag_jogo]
	and	al,11111101b	;altera apenas o bit de movimentacao
	mov	[flag_jogo],al

	;zera contador de tempo da raquete
move_raqFim:
	xor	al,al
	mov	[cont_temp_raq],al	;zera flag de movimento.



	
; colore a barra na posicao corrente e apaga a posicao anterior.
colore_raquete:
	mov	al,[flag_jogo]
	test	al,10b	;testa se a barra se movimentou.
	jnz	main10

	mov	di,[raqPos_ant]	;apaga posicao anterior da raquete.
	xor	ch,ch
	mov	cl,[tam_raquete]
	mov	ax,cor_campo
	call	plot_lin

	mov	di,[raqPos_atual]	;colore posicao atual da raquete.
	mov	ax,cor_raquete
	call	plot_lin

	mov	[raqPos_ant],di	;atualiza a posicao anterior da raquete.
	mov	al,[flag_jogo]	;seta o bit que marca o fim da movimentacao
	or	al,10b		;da raquete.
	mov	[flag_jogo],al


; colore a bola na posicao corrente e apaga a posicao anterior.
main10:
	test	al,100b	;testa se a bola se movimentou.
	jnz	placar

	; apaga posicao anterior
	mov	di,[bolaPos_ant] ;apaga a posicao anterior da bola.
	xor	ch,ch
	mov	cl,[tam_bola]	 ;numero de colunas a pintar.
	mov	bx,cx		 ;numero de linhas a pintar.
	mov	ax,cor_campo
main11:
	call	plot_lin
	dec	bx
	add	di,colunas_video
	cmp	bx,0
	jne	main11

	; colore posicao atual
	mov	di,[bolaPos_atual]
	push	di	;salva posicao usada para colorir bola
	mov	ax,cor_bola
	mov	bx,cx	;numero de linhas a pintar eh menor.
main12:
	call	plot_lin
	dec	bx
	add	di,colunas_video
	cmp	bx,0
	jne	main12

; atualiza a posicao anterior da bola
	pop	di	;recupera a posicao atual da bola.
	mov	[bolaPos_ant],di
	mov	al,[flag_jogo]	;seta o bit que marca o fim do movimento
	or	al,100b		;da bola.
	mov	[flag_jogo],al



; escreve placar na tela 
placar:
	mov	bl,[flag_jogo]
	test	bl,10000b		;testa se placar mudou.
	jz	placar5			;pula se mudou.
	
	jmp	placar15


	;apaga numero anterior
placar5:
	mov	bl,[flag_jogo]
	or	bl,00010000b
	mov	[flag_jogo],bl
	mov	si,enderecos_seg	;tabela de enderecos dos segmentos do placar.
	mov	bx,numeros_seg		;indica quais segmentos devem ser coloridos.
	xor	cx,cx
	mov	cl,tam_seg		;tamanho de cada segmento.

	mov	ax,cor_campo
	mov	di,[si]			;pixel mais acima e a esquerda da area do placar.
	add	cl,cl
	dec	cl			;altura da area do placar
	mov	dl,tam_seg
	inc	dl			;segmentos horizontais maiores.
placar10:
	call	plot_col
	dec	dl
	add	di,2			;proxima coluna.
	cmp	dl,0
	ja	placar10


	;escreve numero no placar
placar15:
	mov	si,enderecos_seg	;tabela de enderecos dos segmentos do placar.
	mov	bx,numeros_seg		;indica quais segmentos devem ser coloridos.
	mov	al,[pontuacao_user]
	mov	ah,7
	mul	ah			;indica a linha da tabela de numeros_seg.
	add	bx,ax
	mov	dh,7			;conta quantos segmentos ainda precisam ser pintados.
placar20:
	mov	al,[bx]			;pega qual segmento deve ser colorido.
	cmp	al,9
	je	main
	cmp	dh,0
	je	main

	xor	ah,ah
	dec	dh
	inc	bx			;proxima coluna da tabela.
	mov	dl,al
	add	al,al			;endereco de word.
	push	si
	add	si,ax
	mov	di,[si]
	pop	si
	test	dl,1b			;verifica se o numero contido eh impar ou par
	jz	placar30			;pula se for par

	;numero impar (segmentos horizontais)
	mov	ax,cor_placar
	mov	cl,tam_seg
	inc	cl
	call	plot_lin
	jmp	placar20

	;numero par (segmentos verticais)
placar30:
	mov	cl,tam_seg
	mov	ax,cor_placar
	call	plot_col
	jmp	placar20




;retorna para o loop principal do jogo
	jmp	main	

;;;;;;;;;;;;;;;;;;;;;;;
; termino do programa
;;;;;;;;;;;;;;;;;;;;;;;
main_fim:

; restaura condicao original da int 9
	cli
	xor	ax,ax		;zera ax.
	mov	es,ax
	mov	ax,[int9_orig]
	mov	[es:int9*4],ax	;restaura offset.
	mov	ax,[int9_orig+2]
	mov	[es:int9*4+2],ax;restaura cs.
	sti

; restaura rotina anterior da int 1Ch
	cli
	mov	ax,[int1Ch_orig]
	mov	[es:int1Ch*4],ax	;restaura offset.
	mov	ax,[int1Ch_orig+2]
	mov	[es:int1Ch*4+2],ax	;restaura segmento cs.
	sti

; restaura o modo de video anterior
	xor	ah,ah         ; Constroi uma tela toda preta (sem nada)
	mov	al,[video_ant]; para limpa-la.
	int	10h

; finaliza tudo e retorna para o DOS
	mov	ax,4C00h
	int	21h


;***************************************************************
; Rotinas auxiliares
;***************************************************************

; Plota elementos em linhas.
; ax = as informacoes sobre cor e caracter.
; cx = quantidade de pixels.
; di = posicao do primeiro pixel.
; es = segmento video
plot_lin:
	push	cx
	push	di

pl1:
	mov	[es:di],ax
	add	di,2
	loop	pl1

	pop	di
	pop	cx
	ret
;fim-plot_lin
;--------------------------------------------------------------

; Plota elementos em colunas.
; ax = as informacoes sobre cor e caracter.
; cx = quantidade de pixels.
; di = posicao do primeiro pixel.
; es = segmento video
plot_col:
	push	cx
	push	di

pc1:
	mov	[es:di],ax
	add	di,colunas_video
	loop	pc1

	pop	di
	pop	cx
	ret
;fim-plot_col
;--------------------------------------------------------------

; Recoloca a bola na posicao inicial
; Tenta variar o angulo de maneira aleatoria
reinicia_bola:
	push	dx
	push	bx
	push	ax
	push	cx
	
	;gerar numero aleatorio
	mov 	ah,0			;pega numero de clock ticks em cx:dx
	int 	1ah
	xor	ch,dl
	xor	dh,dl
	xor	cl,dh			;cx eh o numero aleatorio.



	;variar angulo da bola (de acordo com ch)
	mov	dh,ch
	and	dh,00000011b		;deixa apenas 4 possiblidades.

	cmp	dh,0
	jne	var_angulo1
	mov	ah,2			;numero de passos.
	mov	[desloc_y],ah		;2 passos em y.
	mov	[desloc_x],ah		;1 passo em x
	jmp	var_pos

var_angulo1:
	cmp	dh,2
	jne	var_angulo2

	mov	ah,4
	mov	[desloc_x],ah		;2 passos em x.
	mov	ah,1
	mov	[desloc_y],ah		;1 passos em y.
	jmp	var_pos

var_angulo2:
	mov	ah,1
	mov	[desloc_y],ah		;1 passo em y.
	inc	ah
	mov	[desloc_x],ah		;1 passo em x.


	;varia posicao inicial da bola
var_pos:
	mov	bl,colunas_video
	mov	bh,[tam_bola]
	add	bh,bh
	sub	bl,bh		;bl area disponivel na horizontal.
	xor	ax,ax
	mov	al,bl
	mov	bl,[desloc_x]
	div	bl			
	mov	bl,al		;bl guarda o numero de deslocamentos possiveis.

	mov	ax,cx		;numero aleatorio.
	xor	bh,bh
	xor	dx,dx
	div	bx			;dl = numero de deslocamentos a serem feitos

	mov	al,dl
	mov	bl,[desloc_x]
	mul	bl
	xor	ah,ah
	mov	[bolaPos_atual],ax
	mov	[ja_desloc_x],al

	;varia em direcao
	test	ch,10b
	jz	rein_bola30		;pula se for p/ direita.
	mov	al,[flag_jogo]
	and	al,10111111b		;seta p/ esquerda.
	mov	[flag_jogo],al
	jmp	rein_bola_fim 
	
rein_bola30:
	mov	al,[flag_jogo]
	or	al,01000000b		;seta p/ direita.
	mov	[flag_jogo],al

rein_bola_fim:
	xor	dl,dl
	mov	[ja_desloc_y],dl	;comeca encostada no topo
	pop	cx
	pop	ax
	pop	bx
	pop	dx
	ret

;fim-reinicia_bola 
;--------------------------------------------------------------

; Colore todo o campo
; es = segmento de video
colore_campo:
	push	ax
	push	cx
	push	di

	xor	di,di
	mov	ax,cor_campo	;colore todo o campo e apaga a mensagem.
	mov	cx,tam_video
	call	plot_lin

	pop	di
	pop	cx
	pop	ax
	ret

;fim-colore_campo
;--------------------------------------------------------------

;imprime um caracter
; al = byte em ASCII
printchar:
	push	ax
	push	dx

	mov	dl,al
	mov	ah,2
	int	21h

	pop	dx
	pop	ax
	ret
;fim-printchar
;--------------------------------------------------------------

; Imprime 1 caracter em decimal
; al = caracter em decimal
; funcao recursiva.
printchar_dec:
	cmp	al,0
	jne	printD10	;pula se al for diferente de zero.

	push	ax
	push	dx
	mov	dl,'0'		;imprime zero e sai.
	mov	ah,2
	int	21h
	pop	ax
	pop	dx
	ret

printD10:
	push	ax
	push	dx
	mov	ah,0
	cmp	ax,0
	je	printDfim

	mov	dl,10
	div	dl
	call	printD10
	mov	dl,ah	;ah guarda o resto da divisao.
	add	dl,30h
	mov	ah,2
	int	21h
	jmp	printDfim

printDfim:
	pop	dx
	pop	ax
	ret
;fim-printchar_dec
;--------------------------------------------------------------

;Imprime mensagens como string e seta cursor
;dx = mensagem
print_string:
	push	ax
	push	bx
	push	dx

	mov	ah,2	;setar posicao do cursor.
	mov	bh,0	;pagina (s/ importancia).
	mov	dl,colunas_video/2-70	;posicao no eixo x
	mov	dh,linhas_video/2-15	;posicao no eixo y
	int	10h	;interrupcao de video.

	pop	dx
	mov	ah,9
	int	21h	;imprime mensagem

	pop	bx
	pop	ax
	ret
;fim-print_string
;--------------------------------------------------------------

; Rotina de delay.
; Tempo definido em tempo_delay e contador usado eh cont_temp_bola.
; Zera contador de tempo.
delay:
	push	ax
	xor	ah,ah
	mov	[cont_temp_bola],ah	;zera contador.

delay_wait:
	mov	ah,[cont_temp_bola]
	cmp	ah,tempo_delay	;tempo de exibicao de mensagem.
	jb	delay_wait

	pop	ax
	ret
;fim-delay
;--------------------------------------------------------------

; Rotina de congelamento da bola e da barra.
congela_jogo:
	push	ax

	mov	al,[flag_jogo]
	or	al,00001000b
	mov	[flag_jogo],al		;congela bola e raquete.

	pop	ax
	ret
;fim-congela_jogo
;--------------------------------------------------------------

; Rotina de descongelamento da bola e da barra.
; Indica mudanca na posica da bola, raquete e placar.
descongela_jogo:
	push	ax

	mov	al,[flag_jogo]
	and	al,11100001b
	mov	[flag_jogo],al		;descongela bola e raquete.

	pop	ax
	ret
;fim-congela_jogo
;--------------------------------------------------------------









;--------------------------------------------------------------
; nova rotina de interrupcao da int 9
;--------------------------------------------------------------
intTeclado:
	push	ax
	push	cx
	push	ds
	mov	ax,cs
	mov	ds,ax
	
	mov	al,0ADh		;desativa teclado.
	call	comTec		;envia comando de desativacao.
	cli
	xor	cx,cx
intT10:			;espera por dados do teclado.
	in	al,64h
	test	al,10b	;verifica se tem dados no buffer.
	loopnz	intT10
	in	al,60h	;pega dados do teclado.

;verifica se o usuario apertou tecla ESC
	cmp	al,tc_sair	
	jne	intT11
	mov	ah,[flag_jogo]
	and	ah,11111110b	;altera apenas o bit de encerramento do jogo.
	mov	[flag_jogo],ah
	jmp	intTfim

;verifica se usuario deseja reiniciar o jogo
intT11:
	mov	ah,[bolas_user]	;recupera quantidade de bolas do usuario.
	cmp	ah,0
	jne	intT15	;pula se as bolas do usuario ainda nao acabaram.
	cmp	al,tc_recomecar	;verifica se eh a tecla "s".
	jne	intT15	;pula se usuario ainda nao se decidiu.
	mov	ah,Nbolas_inicial
	mov	[bolas_user],ah	;usuario com quantidade de bolas inicial.

;verifica se o movimento da barra esta habilitado.
intT15:
	;mov	ah,[flag_jogo]
	;test	ah,1000b	;bit de habilitacao da raquete
	;jnz	intTfim	;pula se esta desabilitada



;verifica movimentacao para esquerda
	cmp	al,mvl_down	
	jne	intT25
	;seta mudanca na posicao p/ esquerda
	mov	ah,[flag_raquete]
	or	ah,00000010b		;moveu p/ esquerda.
	mov	[flag_raquete],ah
	jmp	intTfim
	;zera mudanca na posicao p/ esquerda
intT25:
	cmp	al,mvl_up
	jne	intT30		;pula p/ verificar movimentacao p/ direita.
	mov	ah,[flag_raquete]
	and	ah,11111101b
	mov	[flag_raquete],ah
	jmp	intTfim



;verifica movimentacao para direita
intT30:
	cmp	al,mvr_down
	jne	intT35
	;seta mudanca na posicao p/ direita
	mov	ah,[flag_raquete]
	or	ah,00000001b		;moveu p/ direita.
	mov	[flag_raquete],ah
	jmp	intTfim
	;zera mudanca de posicao p/ direita
intT35:
	cmp	al,mvr_up
	jne	intTfim
	mov	ah,[flag_raquete]
	and	ah,11111110b
	mov	[flag_raquete],ah




;finalizacao da rotina
intTfim:
	mov	al,0AEh	;reabilita teclado.
	call	comTec

	mov	al,20h	;sinaliza fim de interrupcao.
	out	20h,al
	pop	ds
	pop	cx
	pop	ax
	iret
;fim-intTeclado
;---------------------------------------------------------

; rotina de envio de comando para 8042.
; comando eh passado por al.
comTec:
	push	cx
	push	ax	;salva comando.
	cli
	xor	cx,cx
comT10:			;espera 8042 ficar pronto.
	in	al,64h
	test	al,10b	;verifica se o buffer de entrada esta cheio
	loopnz	comT10
	
	pop	ax	;retoma o comando a ser dado.
	out	64h,al
	sti
	pop	cx
	ret
;fim-comTec
;------------------------------------------------------





;------------------------------------------------------
; Interrupcao de tempo
;------------------------------------------------------

; nova rotina para interrupcao de tempo, que eh chamada a
; cada 55ms.
intTempo:
	push	ax
	push	bx
	push	cx
	push	ds
	push	di
	push	es
	mov	ax,cs
	mov	ds,ax

; atualiza o tempo p/ bola
	mov	al,[cont_temp_bola]
	inc	al
	mov	[cont_temp_bola],al	;atualiza o tempo.

; verifica se a bola esta livre p/ se movimentar
	mov	bl,[flag_jogo]
	test	bl,1000b	;bit de habilitacao da rotina.
	jz	skipJmp50	;truque para aumentar pulo.
	jmp	intTempoFim ;encerra interrupcao se a rotina estiver desabilitada.
skipJmp50:


; atualiza tempo de placar, se bola e barra estao em movimento
	mov	al,[cont_temp_plac]
	inc	al
	mov	[cont_temp_plac],al

; atualiza tempo da raquete, se bola e barra estao em movimento
	mov	al,[cont_temp_raq]
	inc	al
	mov	[cont_temp_raq],al


; determina a velocidade da bola
	mov	al,[cont_temp_bola]
	cmp	al,[vel_bola]
	jnb	skipJmp10	;truque para aumentar salto
	jmp	intTempoFim ;se ainda nao atingiu o tempo necessario, nada a fazer.
skipJmp10:
	

; modifica a posicao da bola
; verifica os quatro diferentes sentidos possiveis para a bola.
; bl-> eh usado sempre como flag_jogo


;ATENCAO -> numeracao dos labels invertida porque foi preciso torcar 
; um grande bloco de codigo.


;verifica qual o sentido na vertical.
	test	bl,10000000b	;verifica bit cima/baixo.
	jz	skipJmp25	;truque p/ aumentar pulo.
	jmp	intTempo25	;pula se for p/ cima.
skipJmp25:

	;movimento p/ baixo
	mov	al,[desloc_max_y]
	cmp	al,[ja_desloc_y] ;se a bola tocou o fundo da tela.
	jna	intTempo22	;pula se tocou.

		;bola ainda nao tocou o fundo
	mov	cx,[bolaPos_atual] ;recupera posicao da bola.
	mov	al,[desloc_y]	;al p/ poder multiplicar.
	mov	bh,colunas_video
	mul	bh	;salta linhas na tela.
	add	cx,ax	;movimenta bola p/ baixo.
	mov	[bolaPos_atual],cx ;atualiza posicao da bola.
	mov	al,[ja_desloc_y]
	mov	cl,[desloc_y]
	add	al,cl
	mov	[ja_desloc_y],al ;altera quantidade ja deslocada.
	jmp	intTempo20 ;verifica na horizontal

		;bola tocou o fundo, mas precisa verificar se eh a barra.
intTempo22:
	mov	di,[bolaPos_atual] ;recupera a posicao da bola.
	mov	al,[tam_bola]
	mov	bh,colunas_video 
	mul	bh	;salta para a primeira linha depois da bola.
	add	di,ax ;comeca a verificar a ultima linha da tela.
	mov	ax,seg_video
	mov	es,ax		;segmento de video p/ verificar cor da tela.
	xor	cx,cx
	mov	cl,[tam_bola]
intTempo23:		;verifica se a bola toca em algum ponto da raquete.
	mov	ax,[es:di] 
	cmp	ax,cor_raquete	;byte impar contem informacoes de cor de fundo.
	je	intTempo24 ;pula se a raquete esta em baixo.
	add	di,2	;proxima posicao de memoria.
	loop	intTempo23	;verifica proxima posica de memoria.


		;a raquete nao esta em baixo, entao seta que uma bola foi perdida.
	and	bl,11011111b	;set que o usuario perdeu uma bola.	
	jmp	intTempo30	;finaliza movimentacao.


		;a raquete esta em baixo e a bola deve ser rebatida.
intTempo24:
	or	bl,10000000b	;seta direcao p/cima
	mov	cx,[bolaPos_atual] ;recupera posicao da bola.
	mov	al,[desloc_y]
	mov	bh,colunas_video
	mul	bh	;salta linhas na tela.
	sub	cx,ax	;movimenta bola p/ cima.
	mov	[bolaPos_atual],cx ;atualiza posicao da bola.
	mov	al,[desloc_max_y]
	mov	cl,[desloc_y]
	sub	al,cl
	mov	[ja_desloc_y],al ;altera quantidade ja deslocada.
	jmp	intTempo20 ;verifica na horizontal
	

	;movimento p/cima
intTempo25:
	xor	al,al
	cmp	al,[ja_desloc_y] ;se a bola tocou o topo da tela.
	jb	intTempo26	;pula se ainda nao encostou.

		;bola tocou o topo
	and	bl,01111111b	;seta direcao p/ baixo.
	mov	cx,[bolaPos_atual] ;recupera posicao da bola.
	mov	al,[desloc_y]
	mov	bh,colunas_video
	mul	bh	;salta linhas na tela.
	add	cx,ax	;movimento p/ baixo.
	mov	[bolaPos_atual],cx ;atualiza posicao da bola.
	mov	al,[ja_desloc_y]
	mov	cl,[desloc_y]
	add	al,cl
	mov	[ja_desloc_y],al ;altera quantidade ja deslocada.
	jmp	intTempo20 ;verifica na horizontal

		;bola ainda nao tocou o topo.
intTempo26:
	mov	cx,[bolaPos_atual] ;recupera posicao da bola.
	mov	al,[desloc_y]
	mov	bh,colunas_video
	mul	bh	;salta linhas na tela.
	sub	cx,ax	;movimento p/ cima.
	mov	[bolaPos_atual],cx ;atualiza posicao da bola.
	mov	al,[ja_desloc_y]
	mov	cl,[desloc_y]
	sub	al,cl
	mov	[ja_desloc_y],al ;altera quantidade ja deslocada.


;verifica qual o sentido na horizontal
intTempo20:
	xor	cx,cx	;zera cx pois cl eh usado para somar deslocamentos.
	test	bl,01000000b	;bit de direita/esquerda.
	jnz	intTempo10	;pula p/ movimento p/ direita.
	
	;movimento p/ esquerda
	xor	ax,ax
	cmp	al,[ja_desloc_x]	;se a bola tocou o lado esquerdo da tela.
	jb	intTempo9	;pula se ainda nao encostou.

	;bola encostou
	or	bl,01000000b	;seta direcao p/ direita.
	mov	ax,[bolaPos_atual] ;recupera posicao da bola.
	mov	cl,[desloc_x]	;ch precisa ser zero!
	add	ax,cx	;movimenta bola p/ direita.
	mov	[bolaPos_atual],ax ;atualiza posicao da bola.
	mov	al,cl
	mov	[ja_desloc_x],al ;altera quantidade ja deslocada.
	jmp	intTempo30 ;finalizacao do movimento

	;bola ainda nao encostou.
intTempo9:
	mov	ax,[bolaPos_atual] ;recupera posicao da bola.
	mov	cl,[desloc_x]	;ch precisa ser zero!
	sub	ax,cx	;movimenta bola p/ esquerda.
	mov	[bolaPos_atual],ax ;atualiza posicao da bola.
	mov	al,[ja_desloc_x]
	sub	al,cl
	mov	[ja_desloc_x],al ;altera quantidade ja deslocada.
	jmp	intTempo30 ;finalizacao do movimento

	;movimento p/ direita
intTempo10:
	mov	al,[desloc_max_x]
	cmp	al,[ja_desloc_x] ;se a bola tocou o lado direito da tela.
	ja	intTempo15	;pula se ainda nao tocou.

	;bola encostou
	and	bl,10111111b	;seta direcao p/ esquerda
	mov	ax,[bolaPos_atual] ;recupera posicao da bola.
	mov	cl,[desloc_x]	;ch precisa ser zero.
	sub	ax,cx	;movimenta bola p/ esquerda.
	mov	[bolaPos_atual],ax ;atualiza posicao da bola.
	mov	al,[desloc_max_x]
	sub	al,cl
	mov	[ja_desloc_x],al ;altera quantidade ja deslocada.
	jmp	intTempo30 ;finalizacao do movimento

	;bola ainda nao encostou
intTempo15:
	mov	ax,[bolaPos_atual] ;recupera posicao da bola.
	mov	cl,[desloc_x]	;ch precisa ser zero!
	add	ax,cx	;movimenta bola p/ direita.
	mov	[bolaPos_atual],ax ;atualiza posicao da bola.
	mov	al,[ja_desloc_x]
	add	al,cl
	mov	[ja_desloc_x],al ;altera quantidade ja deslocada.


; indica que a bola ja se movimentou e zera o tempo.
intTempo30:
	xor	al,al
	mov	[cont_temp_bola],al	;zera o tempo passado.
	and	bl,11111011b	;seta o bit de movimentacao da bola.
	mov	[flag_jogo],bl

intTempoFim:
	pushf		;simular uma interrupcao (int = pushf+call).
	call	far [int1Ch_orig]	;chama a interrupcao int 1Ch original.
	pop	es
	pop	di
	pop	ds
	pop	cx
	pop	bx
	pop	ax
	iret
;fim-intTempo
;-----------------------------------------------------------


;###############################################################
; DADOS
;###############################################################

	segment	.data
; dados sobre a raquete
tam_raquete_ini	equ	0Fh		;tamanho 15 no nivel zero
temp_mov_raq	equ	1		;tempo p/ movimentar raquete.

raqPos_atual	dw	raqPos_ini	;posicao atual da raquete (posicao memoria).
raqPos_ant	dw	raqPos_atual	;posicao anterior da raquete.
rmax_pos	dw	fim_video-30	;posicao max final (posicao memoria) ATENCAO ACIMA
tam_raquete	db	tam_raquete_ini	;tamanho da raquete (numero de pixels)
rmin_pos	equ	3840	;posicao mais a esquerda da raquete (posicao memoria)
cor_raquete	equ	7F20h	;fundo cinza, letra branca, caracter SPACE
vel_mov		equ	4	;para somar direatamente na posicao de memoria.
raqPos_ini	equ	rmin_pos+70
flag_raquete	db	00000000b	;indica qual o movimento da raquete
; bit 0: 0->nao se moveu p/ direita; 1->moveu p/ direita
; bit 1: 0->nao se moveu p/ esquerda; 1->moveu p/ esquerda

; dados sobre a bola
; Atencao ao modificar os valores abaixo, varios estao correlacionados.
; A bola comeca no canto superior esquerdo da tela.
; desloc_x e desloc_y ditam o angulo de deslocamento da bola e devem ser
; divisores de (160-tam_bola).
;
; Por enquanto, sao previstos bolas apenas de tamanho 2x2 e 4x4.
bolaPos_atual	dw	0000h	;posicao atual da bola.
bolaPos_ant	dw	bolaPos_atual	;posicao anterior da bola.


Npassos_ini	equ	1	;Npassos para o nivel zero
tam_bola_ini	equ	4	;tamanho da bola no nivel zero.

desloc_ini_x	equ	0	;relativo a posicao inicial da bola.
desloc_x	db	Npassos_ini*2	;(Npassos*2bytes) pos de mem p/ mover a bola em x.
ja_desloc_x	db	desloc_ini_x ;(Npassos*2bytes) pos mem ja deslocadas em x (esq->0).
desloc_max_x	db	160-4	;((colunas_video) - (tam_bola*2bytes)).

desloc_ini_y	equ	0	;relativo a posicao inicial da bola.
desloc_y	db	Npassos_ini	;quantidade de passos p/ deslocar a bola em y.
ja_desloc_y	db	desloc_ini_y ;passos ja realizados em y (comeca no topo).
desloc_max_y	db	24-2	;(linhas da tela - tam_bola). (nao eh memoria)

vel_bola_ini	equ	4
vel_bola	db	vel_bola_ini ;velocidade da bola (quanto maior, mais devagar).
cor_bola	equ	7F20h	;fundo branco, letra vermelha, caracter SPACE
tam_bola	db	tam_bola_ini	;dimensao pixels (tam x tam) para parecer quadrada.


; dados sobre o video e campo
cor_campo	equ	2F20h	;fundo verde, letra branca, caracter SPACE
seg_video	equ	0B800h
tam_video	equ	2000	;quantidade de pixels do video.
fim_video	equ	4000	;offset do ultimo pixel.
colunas_video	equ	160	;numero de colunas (pos memoria).
linhas_video	equ	50	;numero de linhas (pos memoria).

; dados sobre o mostrador de pontos
; O mostrador eh dividido em 7 segmentos de tamanho 3, sendo possivel que
; segmentos diferentes tenham um "pixel" em comum.
; Contando de 0 a 6, segmentos impares sao os horizontais e, os pares, verticais.
;		--1--
;	--0--		--4--
;		--3--
;	--2--		--6--
;		--5--
cor_placar	equ	7F20h	;cor dos numeros do placar (cinza)
tam_seg		equ	3	;tamanho de cada segmento (segmentos horizontais: +1).
enderecos_seg	dw	468, 468, 788, 788, 474, 1108, 794	;enderecos na tela.
numeros_seg	db	0, 1, 2, 4, 5, 6, 9	;segmentos p/ o numero zero.
		db	4, 6, 9, 6, 6, 6, 6	;segmentos p/ o numero 1.
		db	1, 2, 3, 4, 5, 9, 5	;segmentos p/ numero 2.
		db	1, 3, 4, 5, 6, 9, 6	;segmentos p/ numero 3.
		db	0, 3, 4, 6, 9, 6, 6	;segmentos p/ numero 4.
		db	0, 1, 3, 5, 6, 9, 6	;segmentos p/ numero 5.
		db	0, 1, 2, 3, 5, 6, 9	;segmentos p/ numero 6.
		db	1, 4, 6, 9, 6, 6, 6	;segmentos p/ numero 7.
		db	0, 1, 2, 3, 4, 5, 6	;segmentos p/ numero 8.
		db	0, 1, 3, 4, 6, 9, 6	;segmentos p/ numero 9.

; dados sobre interrupcoes de teclado
int9		equ	9h	;interrupcao de teclado.
tec_status	equ	64h	;porta para verificacao de status do teclado.
tec_data	equ	60h	;porta de dados do teclado.

; interrupcao de tempo
int1Ch		equ	1Ch	;interrupcao de tempo (intervalo de 55ms).
cont_temp_bola	db	0	;tempo passado (multiplo de 55ms).
cont_temp_plac	db	0	;tempo passado p/ placar.
cont_temp_raq	db	0	;tempo para movimentacao da raquete.


; dados sobre movimentacao da barra
mvr_down	equ	4Dh	;seta p/ direita pressionada
mvr_up		equ	0CDh	;seta p/ direita solta
mvl_down	equ	4Bh	;seta p/ esquerda pressionada
mvl_up		equ	0CBh	;seta p/ esquerda solta

; dados de interacao com o usuario
Nbolas_inicial	equ	4	;quantidade padrao de bolas do usuario.
bolas_user	db	0	;quantidade de bolas que o usuario tem.
tempo_pont	equ	40	;tempo neceddario p/ incrementar pontuacao_user.
pontuacao_user	db	0 	;tempo de bola em jogo.
nivel_jogo	db	0	;nivel de dificuldade do jogo.
nivel_max	equ	6	;nivel maximo de dificuldade.
flag_jogo	db	01100001b
; 7 6 5 4 3 2 1 0	-> bits da flag
;0: 1->permanece no jogo; 0->sair do jogo
;1: 1->sem movimentacao raquete; 0->movimentou a raquete
;2: 1->sem movimentacao bola; 0->bola movimentou
;3: 1->bola e barra congeladas; 0->bola e barra livres
;4: 1->placar s/ mudanca; 0->placar mudou
;5: 1->bola em jogo; 0->usuario acaba de perder uma bola
;6: 1->bola p/ direita; 0->bola p/ esquerda
;7: 1->bola p/ cima; 0->bola p/ baixo
tc_sair		equ	1	;tecla ESC
tc_recomecar	equ	1Fh	;tecla "s" minusculo
tempo_delay	equ	50	;tempo de bola perdida

; mensagens para o usuario.
msg1		db	"Iniciar novo jogo?"
		db	" s/ESC", 0dh, 0ah, "$"
msg2		db	"Voce perdeu uma bola! "
		db	"Quantidade de bolas restantes: ", "$"
msg3		db	"Voce subiu para o nivel de dificuldade: ", "$"
msg4		db	"Parabens!! Pelo menos isso voce sabe jogar!", 0dh, 0ah, "$"
;-----------------------------------

	segment	.bss
video_ant	resb 1
int9_orig	resw 2	;salva offset e segmento cs original.
int1Ch_orig	resw 2	;tambem salva offset e segmento cs.

	resb	128
stacktop:

; Variacoes do tamanho do deslocamento horizontal para tamanhos da bola:
; 2x2 -> |--- 78 ---| -> passos de 2 ou 6
; 4x4 -> |--- 76 ---| -> passos de 2 ou 4
; 6x6 -> |--- 74 ---| -> passos de 2
; 8x8 -> |--- 72 ---| -> passos de 2, 4, 6, 8 ou 9

; Variacoes do tamanho do deslocamento vertical para tamanhos da bola:
; 2x2 -> |--- 22 ---| -> passos de 2
; 4x4 -> |--- 20 ---| -> passos de 2, 4, 5 ou 10
; 6x6 -> |--- 18 ---| -> passos de 2, 3, 6 ou 9
; 8x8 -> |--- 16 ---| -> passos de 2, 4 ou 8

;	mov	dx,msg2
;	mov	ah,9
;	int	21h
