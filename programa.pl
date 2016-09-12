:- [factos].

% Tempo

	% Transforma um tempo em segundos na representa�ao H:m:s
	tempo_tostring(Tempo, String) :-
		stamp_date_time(Tempo, Data, 'UTC'),
		format_time(atom(String), '%k:%M:%S', Data)
	.

	% Transforma um tempo em segundos em vari�veis Hora, Minutos, Segundos
	tempo_segundos(Hora, Minutos, Segundos, Tempo) :- date_time_stamp(date(1970,1,1,Hora,Minutos,Segundos,0,'UTC',-), Tempo).

	% Calcula a diferen�a entre 2 tempos em segundos
	tempo_diferenca(Tempo1, Tempo2, Diferenca) :- abs(Tempo1 - Tempo2, Diferenca).

	% Armazena o tempo total de atendimento
	tempo_total_set(TempoTotal) :- nb_setval('Tempo total', TempoTotal).

	% Inicializa o tempo total de atendimento
	:- tempo_total_set(0).

	% Devolve o tempo total de atendimento
	tempo_total_get(TempoTotal) :- nb_getval('Tempo total', TempoTotal).

	% Armazena a hora atual da simula��o
	hora_atual_set(HoraAtual) :- nb_setval('Hora atual', HoraAtual).
	
	% Inicializa a hora atual da simula��o
	:- hora_atual_set(0).
	
	% Devolve a hora atual da simula��o
	hora_atual_get(HoraAtual) :- nb_getval('Hora atual', HoraAtual).

% Senhas

	% Transforma um tipo e n� de senha na representacao textual tipo C001
	senha_tostring(Tipo, Numero, String) :-
		upcase_atom(Tipo, TipoMaiusculas),
		% Adiciona zeros � esquerda
		format(atom(NumeroComZeros), '~`0t~d~3+', Numero),
		atom_concat(TipoMaiusculas, NumeroComZeros, String)
	.

	% Devolve o tempo de atendimento de um determinado tipo de senha
	senha_tempo_atendimento(Tipo, Tempo) :-
		tipo_senha(Tipo, Minutos),
		tempo_segundos(0, Minutos, 0, Tempo)
	.

	% Transforma uma senha tipo C001 em vari�veis Tipo e Numero
	senha_fromstring(String, Tipo, Numero) :-
		sub_string(String, 0, 1, Digitos, TipoMaiusculas),
		downcase_atom(TipoMaiusculas, Tipo),
		sub_string(String, 1, Digitos, _, NumeroComZeros),
		atom_number(NumeroComZeros, Numero)
	.

	% Armazena a lista de senhas j� atendidas
	senhas_atendidas_set(Senhas) :- nb_setval('Senhas atendidas', Senhas).

	% Inicializa a lista de senhas j� atendidas
	:- senhas_atendidas_set([]).
	
	% Devolve a lista de senhas j� atendidas
	senhas_atendidas_get(Senhas) :- nb_getval('Senhas atendidas', Senhas).

	% Devolve o n�mero de senhas j� atendidas
	numero_senhas_atendidas(NumeroSenhasAtendidas) :-
		senhas_atendidas_get(SenhasAtendidas),
		length(SenhasAtendidas, NumeroSenhasAtendidas)
	.

	% Marca uma senha como atendida e devolve a hora a que est� despachada
	senha_atendida(Senha, HoraAtendimento, HoraDespachada) :-
		senhas_atendidas_get(Senhas),
		SenhasAtendidas = [Senha|Senhas],
		senhas_atendidas_set(SenhasAtendidas),
		senha_fromstring(Senha, Tipo, Numero),
		senha(Hora, Minutos, Segundos, Tipo, Numero),
		tempo_segundos(Hora, Minutos, Segundos, HoraChegada),
		senha_tempo_atendimento(Tipo, TempoAtendimento),
		tempo_diferenca(HoraChegada, HoraAtendimento, TempoEspera),
		tempo_total_get(TempoTotal),
		NovoTempoTotal is TempoTotal + TempoEspera,
		tempo_total_set(NovoTempoTotal),
		HoraDespachada is HoraAtendimento + TempoAtendimento
	.

	% Devolve a lista de senhas que est�o � espera num determinado momento
	senhas_espera(HoraAtual, Tipo, SenhasEspera) :-
		% Todas at� � hora atual
		findall(Senha,
			(
				senha(Hora, Minutos, Segundos, Tipo, Numero),
				tempo_segundos(Hora, Minutos, Segundos, TempoSenha),
				TempoSenha =< HoraAtual,
				Tipo \= fila,
				Tipo \= media,
				senha_tostring(Tipo, Numero, Senha)
			)
		, Senhas),
		senhas_atendidas_get(SenhasAtendidas),
		% Subtraem-se as j� atendidas
		subtract(Senhas, SenhasAtendidas, SenhasEspera)
	.

	% Devolve o n�mero de senhas que est�o � espera num determinado momento
	numero_senhas_espera(HoraAtual, Tipo, NumeroSenhasEspera) :-
		senhas_espera(HoraAtual, Tipo, SenhasEspera),
		length(SenhasEspera, NumeroSenhasEspera)
	.

	% Transforma as senhas que est�o � espera na representa��o pretendida
	senhas_espera_tostring(HoraAtual, NumeroSenhasEspera, SenhasEspera) :-
		numero_senhas_espera(HoraAtual, _, NumeroSenhas),
		senhas_espera(HoraAtual, _, SenhasEspera),
		atom_concat(NumeroSenhas, ' -> ', NumeroSenhasEspera)
	.

	% Devolve o tipo de senha que tem 3 ou mais senhas � espera
	tipo_senha_mais_a_espera(HoraAtual, Tipo) :-
		aggregate(max(NumeroSenhas),
			(
				% Por cada tipo agrega a contagem do n� de senhas
				tipo_senha(Tipo,_),
				aggregate_all(count,
					(
						% Conta s� as que est�o � espera
						senhas_espera(HoraAtual, Tipo, SenhasEspera),
						member(_, SenhasEspera)
					)
				, NumeroSenhas)
			)
		% Calcula o valor m�ximo de entre todos
		, Maximo),
		Maximo >= 3,
		!
	.

	% Indica qual a proxima senha a atender, indicando qual o tipo de senha preferencial
	proxima_senha(HoraAtual, Tipo, Senha) :-
		% Primeiro caso: existem senhas de um determinado tipo � espera que t�m prioridade
		senhas_espera(HoraAtual, _, SenhasEsperaTodas),
		tipo_senha_mais_a_espera(HoraAtual, TipoMaisAEspera),
		senha(_, _, _, TipoMaisAEspera, NumeroMaisAEspera),
		TipoMaisAEspera \= fila,
		TipoMaisAEspera \= media,
		senha_tostring(TipoMaisAEspera,NumeroMaisAEspera,Senha),
		member(Senha, SenhasEsperaTodas),
		!;
		% Ou n�o, ent�o atende-se a senha preferencial caso exista
		senhas_espera(HoraAtual, Tipo, SenhasEsperaTipo),
		senha(_, _, _, Tipo, Numero),
		Tipo \= fila,
		Tipo \= media,
		senha_tostring(Tipo,Numero,Senha),
		member(Senha, SenhasEsperaTipo),
		!
		% Ou ent�o podem nem existir senhas para atender
	.

% Balcoes

	% Devolve a representa��o textual de um balc�o
	balcao_tostring(Balcao, String) :- atom_concat('Balcao ', Balcao, String).

	% Armazena a hora (em segundos) em que o balc�o est� livre
	balcao_livre_set(Balcao, Livre) :-
		balcao_tostring(Balcao, String),
		atom_concat(String, ' hora livre', String2),
		nb_setval(String2, Livre)
	.
	
	% Inicializa a hora (em segundos) em que o balc�o est� livre
	balcoes_init :-
		foreach(balcao(Balcao),
			balcao_livre_set(Balcao, 0)
		)
	.
	
	% Devolve a hora (em segundos) em que o balc�o est� livre
	balcao_livre_get(Balcao, Livre) :-
		balcao_tostring(Balcao, String),
		atom_concat(String, ' hora livre', String2),
		nb_getval(String2, Livre)
	.

	% Devolve os balc�es que est�o livres num determinado instante
	balcao_livre(Hora, Balcao) :-
		balcao(Balcao),
		balcao_livre_get(Balcao, Livre),
		Livre =< Hora
	.

% Programa

	% Executa a simula��o
	simulacao :-

		% Inicializa as vari�veis
		tempo_total_set(0),
		hora_atual_set(0),
		senhas_atendidas_set([]),
		balcoes_init,

		% Devolve a hora inicial da primeira senha
		senha(HoraInicial,_,_,_,_),
		!,
		% Percorre as 24 horas, cada minuto e cada segundo...
		forall(between(HoraInicial,23,Hora),
			(
				forall(between(0,59,Minutos),
					(
						forall(between(0,59,Segundos),
							(
								% Transforma numa representa��o em segundos
								tempo_segundos(Hora, Minutos, Segundos, HoraAtual),
								hora_atual_set(HoraAtual),
								tempo_tostring(HoraAtual, HoraString),

								% Se existirem senhas que entraram na hora atual, escreve no ecr�
								forall(senha(Hora, Minutos, Segundos, Tipo, Numero),
									(
										Tipo \= fila,
										Tipo \= media,
										senha_tostring(Tipo, Numero, SenhaEntrada),
										write(HoraString),
										write(' senha '),
										write(SenhaEntrada),
										nl;
										% Ou se n�o existirem continua-se
										true
									)
								),
								% Percorrem-se os balc�es livres...
								forall(balcao_livre(HoraAtual, Balcao),
									(
										% E os tipos de senha que atendem...
										forall(balcao_senha(Balcao, TipoSenha),
											(
												% E atende-se a proxima senha
												balcao_livre(HoraAtual, Balcao),
												proxima_senha(HoraAtual, TipoSenha, Senha),
												senha_atendida(Senha, HoraAtual, HoraDespachada),
												balcao_livre_set(Balcao, HoraDespachada),
												balcao_tostring(Balcao, BalcaoString),
												write(HoraString),
												write(' senha '),
												write(Senha),
												write(' -> '),
												write(BalcaoString),
												nl;
												% Ou se n�o houver senha para atender continua-se
												true
											)
										)
									)
								),
								% Verifica-se se existem comandos de fila para esta hora
								forall(senha(Hora, Minutos, Segundos, fila, 0),
									(
										write(HoraString),
										write(' Senhas em espera: '),
										senhas_espera_tostring(HoraAtual, NumeroSenhas, Fila),
										write(NumeroSenhas),
										write(Fila),
										nl;
										true
									)
								),
								% Verifica-se se existem comandos de m�dia para esta hora
								forall(senha(Hora, Minutos, Segundos, media, 0),
									(
										tempo_total_get(TempoTotal),
										numero_senhas_atendidas(NumeroSenhasAtendidas),
										Media is TempoTotal / NumeroSenhasAtendidas,
										stamp_date_time(Media, Data, 'UTC'),
										format_time(atom(TempoMedio), '%Mm%Ss', Data),
										write(HoraString),
										write(' Tempo m�dio de espera: '),
										write(TempoMedio),
										nl;
										true
									)
								)
							)
						)
					)
				)
			)
		)
	.