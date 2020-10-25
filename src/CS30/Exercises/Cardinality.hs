{-# LANGUAGE TemplateHaskell #-}

{-
authors: Bennett Clark & Donia Tung
COSC 69.14, 20F
Group Assignment 1 
-}

module CS30.Exercises.Cardinality (cardEx) where
import           CS30.Data
import           CS30.Exercises.Data
import           CS30.Exercises.Util
import           Data.List.Extra (intercalate)
import qualified Data.Map as Map
import qualified Data.Set as Set
import           Data.Functor.Identity
import           Data.Void
import           Text.Megaparsec
import           Text.Megaparsec.Char -- readFile
import qualified Text.Megaparsec.Char.Lexer as L
import           Control.Monad.Combinators.Expr
import Debug.Trace

data CardExp = CardExp deriving Show
-- type CardExp a = ([Field],a)
-- $(deriveJSON defaultOptions ''CardExp)

data MathExpr = Const Integer 
              | Fact MathExpr            -- factorial
              | Divide MathExpr MathExpr  -- division
              | Mult  MathExpr MathExpr  -- multiply two MathExpr's 
              | Expon MathExpr MathExpr  -- set first MathExpr to the second MathExpr power
              | Choose MathExpr MathExpr -- first MathExpr `choose` second MathExpr
              deriving Show

-- fxn for calculating choose operation
choose :: Integer -> Integer -> Integer
choose n r | n >  r = ((choose (n-1) r) * n) `div` (n-r)
           | n <  r = 0
           | otherwise = 1 

-- fxn for calculating factorials
factorial :: Integer -> Integer
factorial 0 = 1
factorial n | n > 0 = n * factorial (n-1)
            | n == 0 = 1
            | otherwise = undefined

-- function for executing the math of a MathExpr 
evalExpr :: MathExpr -> Maybe Integer
evalExpr (Const x)    = return x
evalExpr (Fact e)     = do {x <- evalExpr e; return (factorial x)} 
evalExpr (Mult e1 e2) = do {x1 <- evalExpr e1; x2 <- evalExpr e2; return (x1 * x2)}
evalExpr (Expon e1 e2) = do {x1 <- evalExpr e1; x2 <- evalExpr e2; return (x1 ^ x2)}
evalExpr (Choose e1 e2) = do {x1 <- evalExpr e1; x2 <- evalExpr e2; return (x1 `choose` x2)}
evalExpr (Divide e1 e2) = do x1 <- evalExpr e1
                             x2 <- evalExpr e2 
                             if (x2 == 0 || (x1 `rem` x2) /= 0) then Nothing
                             -- ^ all answers should be valid integers, so there's something wrong if 
                             -- either the denominator is 0 or the numerator doesn't divide the denominator
                             else return (x1 `div` x2)

-- fxn for extracting the numbers in a math expression 
getNums :: MathExpr -> [Integer]
getNums (Const x)    = [x]
getNums (Fact e)     = getNums e  
getNums (Mult e1 e2) = getNums e1++getNums e2
getNums (Expon e1 e2) = getNums e1++getNums e2
getNums (Choose e1 e2) = getNums e1++getNums e2
getNums (Divide e1 e2) = getNums e1++getNums e2

-- cardEx definition for export to Pages.hs
cardEx :: ExerciseType
cardEx = exerciseType "Cardinality" "L??" "Cardinality of Expression" 
            cardinality
            cardQuer 
            cardFeedback

-- for selecting a random int for question generation
allCards :: [Integer]
allCards = [1..99] 

-- fxn for generating questions & solutions, 4 diff types of questions, implemented as nodes/Branches in the choice tree
cardinality :: [ChoiceTree ([[Field]], [Integer])]
cardinality = [ 
            -- cardinality of the cartesian product of two sets
           nodes [ ( [[FMath$ "|A| = "++(show n1), FText" and ", FMath$"|B| = "++(show n2)], -- rule
                      [FMath$ "|A \\times B|"],  -- question 
                      [FMath$ (show n1), FMath$"\\cdot",  FMath$ (show n2)] -- intermediate step, before # solution
                     ]
                     , [n1 * n2, n1, n2] -- calculated solution (head of list) and all # allowed in answer (tail of list)
                     )
                   | n1 <- allCards, n2 <- allCards]
            -- cardinality of a power set
            , nodes [ ( [[FMath"|A| ", FMath$ "= "++(show n1)], 
                        [FText "|𝒫",FMath$ "(A)", FText"|"],
                        [FMath$ "2^{"++(show n1)++"}" ]
                        ]
                     , [2^n1, 2, n1]
                     )
                   | n1 <- allCards]
            -- cardinality of set x its powerset
           , Branch [ nodes [ ( [[FMath"|A| ", FMath$"= "++(show n1)],
                                [FMath$"|A \\times ", FText"𝒫", FMath"(A)|"],
                                [FMath$ (show n1)++"\\cdot 2^{"++(show n1)++"}"]
                                ]
                              ,[n1*(2^n1), 2, n1]
                              )
                            | n1 <- allCards]
                     ] 
            -- cardinality with set builder notatino (like ex from the assignment sheet)
           , Branch [ nodes [ ( [[FMath"|B| ", FMath$ "= "++(show n1)],
                                 [FMath$"\\left|\\left\\{A\\ \\mid\\ A \\subseteq B, \\ |A| ="++(show n2)++"\\right\\}\\right|"], 
                                 [FMath$"\\binom{"++(show n1)++"}{"++(show n2)++"}"] -- e.g. \binom{10}{6}
                                ]
                              , [n1 `choose` n2, n1, n2, n1-n2]
                              )
                            | n1 <- allCards, n2 <- [1..n1-1] ]
                    ]
           ]

-- for generating the actual text of the question displayed to client
cardQuer :: ([[Field]],[Integer]) -> Exercise -> Exercise
cardQuer (quer, _solution) exer 
  = exer { eQuestion=[FText "Given "] ++ rule ++ 
                     [FText ", compute "] ++ question ++ 
                     [FFieldMath "answer"]}
                        where rule = head quer
                              question = quer!!1

-- helper fxn to get from list to strings
list_to_string :: [Integer] -> String
list_to_string = intercalate ", " . map show

-- fxn for generating feedback to the users, based on their parsed input
cardFeedback :: ([[Field]],[Integer]) -> Map.Map String String -> ProblemResponse -> ProblemResponse
cardFeedback (quer, sol) mStrs defaultRsp 
  = reTime $ case pr of 
      Just v -> if Set.fromList numInAns `Set.isSubsetOf` (Set.fromList allowedNums) then -- if the user input has the right #s in it
                  case ans of -- look at the evaluated answer
                    Just st -> if st == (head sol) then -- if the calculated answer (from the user input) is the same as our stored solution, then tell the user it's correct!
                                 markCorrect $ defaultRsp{prFeedback = [FText"Correct! "] ++ question ++ [FMath " = "] ++ step ++ [FMath " = "] ++ [FMath (show $ head sol)]} -- TODO: show intermediate steps 
                               else -- otherwise, show them how their math is wrong
                                 markWrong $ defaultRsp{prFeedback = [FText("The correct answer is ")] ++ question ++ [FMath " = "] ++ step ++ [FMath " = "] ++ [FMath(show $ head sol)] ++ 
                                                                     [FText(". You wrote ")] ++ [FMath$ (mStrs Map.! "answer") ]}
                    -- | if the evaluated answer has some error (divide by zero, or some fraction does not evaluate to an integer), then mark wrong
                    Nothing -> markWrong $ defaultRsp{prFeedback = [FText("The correct answer is ")] ++ question ++ [FMath " = "] ++ step ++ [FMath " = "] ++ [FMath (show $ head sol)] ++ [FText "We couldn't understand your answer."]}
                else -- if they didn't have the right numbers in their answer, ask them to explain it better, where did they get those answers from?
                  markWrong $ defaultRsp{prFeedback = [FText("Please explain your answer better. Where did you get " ++ list_to_string notInSol  ++" from?")]} 
                where numInAns    = getNums v 
                      allowedNums = tail sol
                      notInSol    = filter (\x -> notElem x allowedNums) numInAns              
      Nothing -> markWrong $ defaultRsp{prFeedback = [FText("The correct answer is ")] ++ question ++ [FMath " = "] ++ step ++ [FMath " = "] ++ [FMath (show $ head sol)] ++ [FText". We couldn't understand your answer."]}
    where usr = Map.lookup "answer" mStrs
          question = quer!!1
          step = quer!!2
          -- parse the user input
          pr :: Maybe MathExpr
          pr = case usr of
                 Nothing -> Nothing
                 Just v -> case parse parseExpr "" v of
                             Left _ -> Nothing -- error (errorBundlePretty str)
                             Right st -> Just st
          ans :: Maybe Integer
          ans = case pr of
                 Just st -> evalExpr st 
                 Nothing -> Nothing

type Parser = ParsecT Void String Identity

spaceConsumer :: Parser ()
spaceConsumer = L.space spaces empty empty 

symbol :: String -> Parser String
symbol = L.symbol spaceConsumer

lexeme :: Parser a -> Parser a
lexeme   = L.lexeme spaceConsumer

-- based on Drill 6.2 scaffold
spaces :: Parser ()
spaces = some spc >> return ()
 where spc = string " " <|> string "\t" <|> string "\n" <|> string "\r"
             <|> string "\\ " <|> string "~"

brackets :: Parser a -> Parser a
brackets = between (symbol "{") (symbol "}")

parens :: Parser a -> Parser a          
parens = between (symbol "\\left(") (symbol "\\right)")

parseConstant :: Parser MathExpr
parseConstant = do
  n <- lexeme L.decimal
  return (Const n)

operatorTable :: [[Operator Parser MathExpr]]
operatorTable =
  [ [postfix "!" Fact],
    [binary "^" Expon] ,
    [binary "\\cdot" Mult, binary "" Mult] ,
    [binary "choose" Choose]
  ]

binary :: String -> (a -> a -> a) -> Operator Parser a
binary name f = InfixL (f <$ symbol name)

postfix :: String -> (a -> a) -> Operator Parser a
postfix name f = Postfix (f <$ symbol name)

parseBinom :: Parser MathExpr
parseBinom = do
  _  <- symbol "\\binom" 
  e1 <- brackets parseExpr 
  e2 <- brackets parseExpr
  return (Choose e1 e2)

parseFrac :: Parser MathExpr
parseFrac = do
  _  <- symbol "\\frac" 
  e1 <- brackets parseExpr
  e2 <- brackets parseExpr
  return (Divide e1 e2)

parseExpr :: Parser MathExpr
parseExpr =  makeExprParser parseTerm operatorTable

parseTerm :: Parser MathExpr
parseTerm = parens parseExpr <|> brackets parseExpr <|> parseConstant <|> parseBinom <|> parseFrac

