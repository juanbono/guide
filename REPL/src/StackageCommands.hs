module StackageCommands(
                        showSnapshots) where

import Common              
import StackageUpdate

showSnapshots :: URL -> IO()
showSnapshots url = do
    SSS snapshots <- fetchStackageSnapshots url
    putStrLn $ "Showing snapshots from " ++ url
    mapM_ (putStrLn.(\s -> "\tSnapshot: " ++ s).show) snapshots