module Main(main) where

import Graphics.Gloss
import Graphics.Gloss.Interface.Pure.Game

-- Janela principal com dimensoes e posicao inicial
window :: Display
window = InWindow "PES (Pong Evolution Soccer)" (600, 600) (0, 0)

-- Cor de fundo da janela
background :: Color
background = dark (dark (dark green))

-- Data do mundo do game
data WorldPES = GameOver String | Game{
 coordBola :: (Float, Float),  -- Coordenadas da bola (x, y)
 velBola :: (Float, Float),  -- Velocidade da bola nos eixos (x, y)
 bastao1 :: (Float, Float, Float),  -- Bastao 1 coordenadas (x, y)
 bastao2 :: (Float, Float, Float)  -- Bastao 2 coordenadas (x, y)
}deriving Show

-- O estado inicial do game
eInicial :: WorldPES
eInicial = Game{
 coordBola = (0, 0), -- Coordenadas da bola
 velBola = (-300, 110), -- Velocidade da bola nos eixos (x,y)
 bastao1 = (290, 0, 3), -- Jogador artificial
 bastao2 = (-290, 0, 0) -- Jogador
}

-- Renderiza o game em uma Picture
render :: WorldPES -> Picture
render (GameOver s) = scale 0.5 0.5
     . translate (-300) 0
     . color yellow
     . text
     $ s
render game = pictures[bola, paredesH, paredesV,
                       cBastao (bastao1 game),
                       cBastao (bastao2 game)]
 where
    -- Cria a bola com raio 15 e cor preta, posicionada em coordBola
    bola = uncurry translate (coordBola game) (color (dark blue) (circleSolid 15))

    -- Criadores de paredes verticais e horizontais, respectivamente
    paredeH :: Float -> Picture
    paredeH y = translate 0 y (color yellow (rectangleSolid 600 5))

    paredeV :: Float -> Float -> Picture
    paredeV x y = translate x y (color yellow (rectangleSolid 5 210))

    -- Criacao de Pictures das paredes verticais e horizontais
    paredesH = pictures [paredeH 297.5, paredeH (-297.5)]
    paredesV = pictures [paredeV 297.5 195, paredeV 297.5 (-195), paredeV (-297.5) (-195), paredeV (-297.5) (195)]

    --  Criador de bastoes
    cBastao :: (Float, Float, Float) -> Picture
    cBastao (x, y, _) = pictures
      [ translate x y (color white (rectangleSolid 10 70)),
        translate x y (color white (rectangleSolid 10 70))]

-- Movimenta o bastao, sendo chamada enquanto as teclas chaves estao pressionadas
attBastao :: Float -> WorldPES -> WorldPES
attBastao vel game = game {bastao2 = (dx,dy,d) }
    where
      -- Coordenadas atuais
      (bx,by,d0) = bastao2 game
      -- Novas coordenadas do bastao2
      (dx,dy,d) = if (d0==vel)
                  then
                    (bx,by,0)
                  else
                    (bx,by,vel)

-- Atualiza as coordenadas da bola e do bastao1 (jogador artificial) e limita os movimentos do bastao2 
attBolaeIA :: Float -> WorldPES -> WorldPES
attBolaeIA _ (GameOver s) = GameOver s
attBolaeIA time game = game { coordBola = (x1, y1), bastao1 = (dx,dy,d1), bastao2 = (cx,cy,d2) }
  where
    -- Atuais coordenadas e velocidade da bola.
    (x, y) = coordBola game
    (vx, vy) = velBola game
    -- Coordenadas e velocidade atuais do bastao 1 e 2
    (ax,ay,d) = bastao1 game
    (bx,by,d0) = bastao2 game
    -- Novas coordenadas da bola
    x1 = x + vx * time
    y1 = y + vy * time

    -- Limita e automatiza a movimentacao do jogador artificial
    d1 = if (ay<(-80))
        then
          3
        else if (ay>80)
        then
          -3
        else
          d
    (dx,dy,_) = (ax,ay+d,d1)
    -- Limita o movimento do bastao do jogador, voltando automaticamente sempre que chega pero do fim do campo
    d2 = if (by-35<=(-290))
        then
          5
        else if (by+35>=290)
        then
          -5
        else
          d0
    (cx,cy,_) = (bx,by+d0,d2)

-- Definicao de tipos para auxiliar as chamadas
type Radius = Float
type Position = (Float, Float)

-- Checa se a bola toca nas paredes verticalmente
pVCollision :: Position -> Radius -> Bool
pVCollision (_, y) raio = nCollision || sCollision
  where
    sCollision = y-raio<=(-297.5) && y-raio>=(-300.5)
    nCollision = y+raio>=297.5 && y+raio<=300.5

-- Checa se a bola toca nas paredes horizontalmente
pHCollision :: Position -> Radius -> Bool
pHCollision (x, y) raio = eCollision || wCollision
  where
    eCollision = ((x-raio)<=(-297.5)) && ((x-raio)>=(-300.5)) && (((y-raio)<=(-90)) || ((y+raio)>=90))
    wCollision = ((x+raio)>=297.5) && ((x+raio)<=300.5) && (((y-raio)<=(-90)) || ((y+raio)>=90))

-- Calcula a distancia entre dois pontos e a retorna como Float
d2p :: Position -> Position -> Float
d2p (x,y) (x1,y1) = sqrt (((x-x1)**2) + ((y-y1)**2))

-- Checa se a bola toca no bastao leste, recebendo a posicao da bola, raio e posicao do bastao
bwCollision :: Position -> Radius -> Position -> Bool
bwCollision (x, y) raio (x1, y1) = wCollision
  where
    wCollision = (y-raio<=y1+35) && (y+raio>=y1-35) && (((x+raio<= -285) && (x+raio>= -295)) || ((x-raio<= -285) && (x-raio>= -295)))

-- Checa se a bola toca no bastao leste, recebendo a posicao da bola, raio e posicao do bastao
beCollision :: Position -> Radius -> Position -> Bool
beCollision (x, y) raio (x1, y1) = eCollision
  where
    eCollision = (y-raio<=y1+35) && (y+raio>=y1-35) && (((x+raio>=285) && (x+raio<=295)) || ((x-raio>=285) && (x-raio<=295)))

-- Checa se a bola toca nas quinas dos bastoes ou das paredes
quinaCollision :: Position -> Radius -> (Position,Position) -> Bool
quinaCollision (x, y) raio ((bx1,by1),(bx2,by2)) = qp1Collision || qp2Collision || qb1Collision || qb2Collision
  where
    qp1Collision = (((d2p (x,y) (297.5,90))<=15) && (y>90)) || (((d2p (x,y) (297.5,-90))<=15) && (y<(-90)))
    qp2Collision = (((d2p (x,y) (-297.5,90))<=15) && (y>90)) || (((d2p (x,y) (-297.5,-90))<=15) && (y<(-90)))
    qb1Collision = (((d2p (x,y) (bx1,by1+35))<=15) && (y+raio>by1+35)) || (((d2p (x,y) (bx1,by1-35))<=15) && (y-raio<by1-35))
    qb2Collision = (((d2p (x,y) (bx2,by2+35))<=15) && (y+raio>by2+35)) || (((d2p (x,y) (bx2,by2-35))<=15) && (y-raio<by2-35))

-- Checa as colisoes da bola e retorna o mundo com as atualizacoes de velocidade
vrfCollision :: WorldPES -> WorldPES
vrfCollision (GameOver s) = GameOver s
vrfCollision game = q
  where
    -- Raio da bola
    raio = 15
    -- As velocidades atuais da bola nos eixos (x, y)
    (vx, vy) = velBola game
    -- Coordenadas dos bastoes
    (x1,y1,d1) = bastao1 game
    (x2,y2,d2) = bastao2 game
    (x,y) = coordBola game

    q = if (x>=315) then GameOver "Voce venceu!"
      else if (x<= -315) then GameOver "Se fodeu!"
      else  game {velBola = (vx1, vy1)}

    -- Var auxiliar para atualizacao de velocidade com colisao vertical
    d = if (vy>350)
        then
          0.75
        else
          1.05

    -- Verifica colisao verticalmente e retorna a nova velocidade
    vy1 = if (pVCollision (coordBola game) raio || quinaCollision (coordBola game) raio ((x1,y1),(x2,y2)))
          then
            -- Atualiza sentido da velocidade no eixo y
            -vy*d
          -- Atualiza a velocidade no eixo x, somando a velocidade do bastao leste a bola
          else if (beCollision (coordBola game) raio (x1,y1))
          then
            --(*10 pois a velocidade do bastao eh significamente menor por conta da implementacao do movimento do teclado)
            vy+(d1*10)
          -- Atualiza a velocidade no eixo x, somando a velocidade do bastao oeste a bola 
          else if (bwCollision (coordBola game) raio (x2,y2))
          then
            --(*10 pois a velocidade do bastao eh significamente menor por conta da implementacao do movimento do teclado)
            vy+(d2*10)
          else
            -- Retorna a mesma velocidade
            vy

    -- Verifica colisao horizontalmente e retorna a nova velocidade
    vx1 = if ((pHCollision (coordBola game) raio))
          then
            -- Atualiza sentido da velocidade no eixo x
            -vx
          else if ((beCollision (coordBola game) raio (x1,y1))) || ((bwCollision (coordBola game) raio (x2,y2)))
          then
            -- Atualiza sentido da velocidade no eixo x
            -vx
          else
            -- Retorna a mesma velocidade
            vx

-- Eventos de teclado
fctKeys :: Event -> WorldPES -> WorldPES

-- Quando a tecla 'r' é pressionada a bola volta ao centro (0, 0) coma velocidade inicial (-300, 110)
fctKeys (EventKey (Char 'r') _ _ _) game = game { coordBola = (0, 0), velBola = (-300, 110) }
-- Quando as teclas cima ou baixo são pressionadas o bastao se move a 2.5 pixels em y
fctKeys (EventKey (SpecialKey KeyUp) _ _ _) game = attBastao 2.5 game
fctKeys (EventKey (SpecialKey KeyDown) _ _ _) game = attBastao (-2.5) game
fctKeys _ game = game

-- Atualiza o mundo do game com a frequencia s (segundos)
update :: Float -> WorldPES -> WorldPES
update s = attBolaeIA s . vrfCollision

-- Frames per second
fps :: Int
fps = 60

main :: IO ()
main = play window background fps eInicial render fctKeys update