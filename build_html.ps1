function Build-Html {
    # Read binary data files
    $gameDataB64 = Get-Content -Path "D:\khent\game_data.b64" -Raw
    $wasmCodeB64 = Get-Content -Path "D:\khent\wasm_code.b64" -Raw
    $wasmFrameworkB64 = Get-Content -Path "D:\khent\wasm_framework.b64" -Raw
    $unityLoader = Get-Content -Path "D:\khent\UnityLoader.js" -Raw
    
    # Image data URIs
    $logoLight = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJoAAACCCAYAAAC+etHhAAAACXBIWXMAAAsSAAALEgHS3X78AAAIhUlEQVR42u2dzW3bSBTH/yFcgNIBg5wDMKccPa5ATAVxKkhUga0KbFdgdmCpglDHnFZAzsGyBHWgPYjcMIQlkm++3sy8P7AInI3tGfKnN+9rZt4cj0eIRLaVySMQudBV/4v3Hz7JE+GvAoACcA2gBLAC8Dj3h/z+9dMfaCKWyntgqfbrvpYU0LxaNBELLQZgFSP/XgW3dIq8LodlD665UgBqAU302nLYB2uh+fOWApqoWw7LC36WrtgvnwKaPanW0kzxs0wsvQsABwEtnbTD0pOFKQFUAlq8aYelIT9LV9cCWnxph9KCnxW1nyagjb+8zmoVzMeat/81Alo4flZntUJTCaZVgtRBy3G5vBOargU0fnoJ1GoF6ael2iZURghZF7AUAhqfl/EQ+YdIQGOg7xH4YmN+moDGwPn/FvkcFfwnj5MH7Y7JSzg4gE1A8/hJv/UI1gantuuP7Z9JLZ8ppTfuHINVA9i1f+4HwciP1CxaKqDdOnj4HVibAVivBSO2l+8CzMpRKYC2sGTN+harnhGMuLKsCoy6OVIAzVQ6gwLWUC7zd9cCmjvloKcz9i1QW5jpx1dwm0wtAXwV0NzoYYY/tB9YrYOFsVC06flcc12GYsRfFNB6TvwXwsPlANZwHtQa5Kr1626JVlRAm/Byng3+vKa1Di7AGsJPtWbrdtxbImhs2oauIofs0FqE2mOoT61GND1IqD4imwJ7FjFkAHDTRl6+IMvbqJdqzQ69Dwx1CVQCml3IvjLwT6hzqV9JTWwFNJ6QVZ7nozRe8voMfBQtBbR4IdOxZtUZqKgBTAEGHSuZQGZF1GpEF7xcWlKDXD4zgcxKOoNaz3wasVpUP22ZMmgxQgbopTPuJwQJYtEEMq10xmoijA1xXHlqoMUKmU4AUONUtZiiDfF3qJRAixkypfEy53RZ7EL00zKBzLs1e5y5HIpFcwRZxRAynXTGmrjUUqLhImbQTEP2lRlkOumMfj1zjqhpjjJW0GKHDJjXXNnXHvQWnpr4fdcxgpYCZAXoe0V19nbuQUtzqNhASwGyzppRtIH+PgTq95exgJYKZCXRQozVM6eKmua4jgG0VCDTsWZPMNOIGVSaIxPISLoHLZ3RwFwPP7Xr1kvbUCaQzdYC9L2i1HRG8H5aJpCRlswFEYrK8Fio+bQ8NNBMQrYPADJf6YxL8B6IH+hgQDMN2Q34ixoAVLC3UWbu8rmGh11hGSPIDswh853OOKc5aQ6TwYh10FKETGe3+ZPl+c1Jc6x9PetMIJskandGg/H2bF01E5dCG8GIFdBShSzXSGe4Cm6mWLWVz4d45QGyTi8IQ7lGOqN2NMYdLu9VeITnXftXniArEL9cpmrqkWBk7fthZB4gS0Fz27N1dbgAm7cAYCpoAhn9pfuwILszvjCL89Eygcy4Vp4syIZbADAGmkCmF01XHn93H/DKYTAyG7RcINPSk+ff3wdry+nBDEFrwL+wzVm+b87LGY1ldOmsBDaydLo7TEDWTxspj2OZHAwIbHRR+9V0pRiNZTJoAhtdC9BPFNLR8sxY7riDJrDRdQf3XazqzN9/B4NKzJQSVBeum4xGh6E4Z+VEaJ7hrplzbMPJAzw3lk4tqtuA7TPC6d74l2hhFNzkssoJY7lFIG1CJpfRAqdbeBcBgNaAXsZxlZOcsinYa2Awt/HRNGyhJIephencQWCwwLQWc19BCgk007CVgcCm0/dPPTxZNwjgEqSQQTMN220gsFWgNQ/aTjHMPTL0OSTQUoWNatVsphgU4d8Ht1M9Ndhq0A9XsXGfek5cCovQQEsRNqpVs2FJSo0PTHCgpQZbA3oHrWmrRjnr7BAyaKnBRt0TkMPsPk+KRat9PDDTB/GlApvOvoBvMJPuUMTv28UAWkqwVaCf929iCaXehLKJBbSUYFtrzEk38qNYtAae7pfPLH/iTcJ2zxC0GvRCtY5Vy4mg1r4elO0LLUzCdgdGrck9UbfXKY35UP2zbaygmYbtmSFsB9B3P1HroNQj3OuYQUsBtnvQ0x2UjgpKWsNrs6nLaxRjh41aMfiGeWUk6vHtXvd5ur4YNmbYqNfuzO3uCKbs5BO02GGjWrXbGQ5+MGUn36DFDJvO6T1TrNoCtIiz9v1gMo+/O1bYqG3fasIcFHFMu5RBixU2nTro2AYSalpjkzposcJG7e4Y20BCCQQaeCo7cQPNBmyKwZyo8zm3gSQHrZu25vCCuYBmGrYX+D8GoNZ4yQ+GrBnA5Jw0TqCZhG2B0wZl37BR5/LadUDBlZ04g2YDttLjXBqYa/umuANszjjhCJpp2F4AHFvo7j34b4/El90/1E8hwLJTX1fgq6r984sGZMMTEBX+JEZrnPJLOr7U1HTHCrTmzYc2NUHtpq25vMw3x+Px/y/ef/iEyPRjhgWzDd4/RJ/xsZ1DQQD87bn/+fvXTwHNoFQLG9UamARPZywUbXA6GowFaBniVg16q3W3zP4w5OPpjIWiHacXEbtFA+gH6dmweHm7hLo4p+wdLlQExKLxSjGYtngN3Fx60YBB2Sk10HRSDDbAc3HzXc3tBaQCms5BeqbBK2D/9rsttxeQgo9mIsUQmt6OWXDx0exqlcAcWR6tnxpocyLEULXlOKjUQAPivwmmFtB4qAGT658tBT0CGiOxuNA+FWuWMmhdwfljC10sftuO68CukLb2+PvugBKnTlaFMNMgGwEtnBfVvazFALw8AN+zEdDCXF4r/Om4yAfgcbswjfXynwlPs6PVz61/d8PMv9tyfnhi0fQsSN1bZpVn/64W0NJYZvv+XT4Az7Z/x/5GZwHN3jLb9++KAXim/bst9wcioLlRl0bpKhJqAF7Uy6aAFod/dxDQRC78uzqESQpo4ft3OwFNZNO/W7YQbkKYxF+t3CKRLUllQCSgieLRf80sS5fCDVbiAAAAAElFTkSuQmCC"
    $logoDark = "data:image/png;base64,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"
    $progressEmptyLight = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAI0AAAASCAYAAABmbl0zAAAACXBIWXMAAAsSAAALEgHS3X78AAAAUUlEQVRo3u3aMQ4AEAxAUcRJzGb3v1mt3cQglvcmc/NTA3XMFQUuNCPgVk/nahwchE2D6wnRIBpEg2hANIgG0SAaRAOiQTR8lV+5/avBpuGNDcz6A6oq1CgNAAAAAElFTkSuQmCC"
    $progressEmptyDark = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAI0AAAASCAYAAABmbl0zAAAACXBIWXMAAAsSAAALEgHS3X78AAAATUlEQVRo3u3aIQ4AIAwEQUr4/5cPiyMVBDOj0M2mCKgkGdAwjYCudZzLOLiITYPrCdEgGkSDaEA0iAbRIBpEA6JBNHx1vnL7V4NNwxsbCNMGI3YImu0AAAAASUVORK5CYII="
    $progressFullLight = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAI0AAAASCAYAAABmbl0zAAAACXBIWXMAAAsSAAALEgHS3X78AAAAQElEQVRo3u3SMREAMAgAsVIpnTvj3xlogDmR8PfxftaBgSsBpsE0mAbTYBowDabBNJgG04BpMA2mwTSYBkzDXgP/hgGnr4PpeAAAAABJRU5ErkJggg=="
    $progressFullDark = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAI0AAAASCAYAAABmbl0zAAAACXBIWXMAAAsSAAALEgHS3X78AAAAO0lEQVRo3u3SQREAAAjDMMC/56EB3omEXjtJCg5GAkyDaTANpsE0YBpMg2kwDaYB02AaTINpMA2Yhr8FO18EIBpZMeQAAAAASUVORK5CYII="
    $webglLogo = "data:image/png;base64,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3v8f4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+P/H4//j/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xj/GP8Y/xJ9H/H88fx//H+P/f4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Mf4x/jH+Fvsv/zXeRQAAAABJRU5ErkJggg=="
    $fullscreen = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAmCAIAAAAnX375AAAACXBIWXMAAAsSAAALEgHS3X78AAABC0lEQVRYw2OUW3eZgb6AiYHuYNTKUStHrRy1koGBgYUSzRbC3LMt5fhYmZEF5ddfoaEvT7z9GnHk/rXPP+gasFc//Lj69jtdrewxlA5VEKSflcj2rX7wnsgQJj/58LEyawtzQiP1zdeS80/5WJmPuqsR1MjMH55FnpU///3f/PijKBsLIzNj3NGHP//9//nv/6FXX17/+INfI+NgbxWgZUFaWaktwAG3b6W9Yo+hNIUWE7ZyhY0iHyszxD4tXo5QBcGV9oq0LfAgljEwMGjxQr1Lat4nJ5PALYPkv5LzT+mXfCi3j2QrtYU54amJTlZq8XKssFG0EOambVwSrP9GGyKjVo5aOWrl0LASABsZTYue2xSgAAAAAElFTkSuQmCC"
    $favicon = "data:image/x-icon;base64,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"

    # CSS
    $css = @"
.webgl-content * {border: 0; margin: 0; padding: 0}
.webgl-content {position: absolute; top: 50%; left: 50%; -webkit-transform: translate(-50%, -50%); transform: translate(-50%, -50%);}
.webgl-content .logo, .progress {position: absolute; left: 50%; top: 50%; -webkit-transform: translate(-50%, -50%); transform: translate(-50%, -50%);}
.webgl-content .logo {background: url('$logoLight') no-repeat center / contain; width: 154px; height: 130px;}
.webgl-content .progress {height: 18px; width: 141px; margin-top: 90px;}
.webgl-content .progress .empty {background: url('$progressEmptyLight') no-repeat right / cover; float: right; width: 100%; height: 100%; display: inline-block;}
.webgl-content .progress .full {background: url('$progressFullLight') no-repeat left / cover; float: left; width: 0%; height: 100%; display: inline-block;}
.webgl-content .logo.Dark {background-image: url('$logoDark');}
.webgl-content .progress.Dark .empty {background-image: url('$progressEmptyDark');}
.webgl-content .progress.Dark .full {background-image: url('$progressFullDark');}
.webgl-content .footer {margin-top: 5px; height: 38px; line-height: 38px; font-family: Helvetica, Verdana, Arial, sans-serif; font-size: 18px;}
.webgl-content .footer .webgl-logo, .title, .fullscreen {height: 100%; display: inline-block; background: transparent center no-repeat;}
.webgl-content .footer .webgl-logo {background-image: url('$webglLogo'); width: 204px; float: left;}
.webgl-content .footer .title {margin-right: 10px; float: right;}
.webgl-content .footer .fullscreen {background-image: url('$fullscreen'); width: 38px; float: right;}
"@

    # UnityProgress
    $unityProgress = @"
function UnityProgress(unityInstance, progress) {
  if (!unityInstance.Module)
    return;
  if (!unityInstance.logo) {
    unityInstance.logo = document.createElement("div");
    unityInstance.logo.className = "logo " + unityInstance.Module.splashScreenStyle;
    unityInstance.container.appendChild(unityInstance.logo);
  }
  if (!unityInstance.progress) {    
    unityInstance.progress = document.createElement("div");
    unityInstance.progress.className = "progress " + unityInstance.Module.splashScreenStyle;
    unityInstance.progress.empty = document.createElement("div");
    unityInstance.progress.empty.className = "empty";
    unityInstance.progress.appendChild(unityInstance.progress.empty);
    unityInstance.progress.full = document.createElement("div");
    unityInstance.progress.full.className = "full";
    unityInstance.progress.appendChild(unityInstance.progress.full);
    unityInstance.container.appendChild(unityInstance.progress);
  }
  unityInstance.progress.full.style.width = (100 * progress) + "%";
  unityInstance.progress.empty.style.width = (100 * (1 - progress)) + "%";
  if (progress == 1)
    unityInstance.logo.style.display = unityInstance.progress.style.display = "none";
}
"@

    # Game boot script (without the base64 data - we'll write it separately)
    $bootPre = @'
function b64ToBlob(b64, mime) {
  var binary = atob(b64);
  var len = binary.length;
  var bytes = new Uint8Array(len);
  for (var i = 0; i < len; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return new Blob([bytes.buffer], {type: mime});
}
var dataBlob = b64ToBlob("
'@
    $bootMid1 = '", "application/octet-stream");'
    $bootMid2 = 'var codeBlob = b64ToBlob("'
    $bootMid3 = 'var frameworkBlob = b64ToBlob("'
    $bootPost = @'
", "application/octet-stream");
var dataUrl = URL.createObjectURL(dataBlob);
var wasmCodeUrl = URL.createObjectURL(codeBlob);
var wasmFrameworkUrl = URL.createObjectURL(frameworkBlob);
var gameConfig = {
  "companyName": "FreezeNova",
  "productName": "Masked Special Forces",
  "productVersion": "0.3",
  "dataUrl": dataUrl,
  "wasmCodeUrl": wasmCodeUrl,
  "wasmFrameworkUrl": wasmFrameworkUrl,
  "graphicsAPI": ["WebGL 2.0","WebGL 1.0"],
  "webglContextAttributes": {"preserveDrawingBuffer": false},
  "splashScreenStyle": "Dark",
  "backgroundColor": "#231F20",
  "cacheControl": {"default": "must-revalidate"},
  "developmentBuild": false,
  "multithreading": false,
  "unityVersion": "2019.4.36f1"
};
var gameJsonStr = JSON.stringify(gameConfig);
var gameJsonUri = "data:application/json;base64," + btoa(gameJsonStr);
function FitScreen(){
  var w = 960;
  var h = 540;
  var availWidth = window.innerWidth;
  var availHeight = window.innerHeight;
  var width, height;
  if(availWidth/availHeight > w/h){
    height = availHeight;
    width = (height*w/h);
  }else{
    width = availWidth;
    height = width*h/w;
  }
  document.getElementById("gameContainer").style.width = width + "px";
  document.getElementById("gameContainer").style.height = height + "px";
}
var gameInstance = UnityLoader.instantiate("gameContainer", gameJsonUri, {onProgress: UnityProgress});
'@

    Write-Output "Writing HTML..."
    
    # Use StreamWriter to write the file piece by piece
    $writer = New-Object System.IO.StreamWriter("D:\khent\Masked_Special_Forces.html", $false, [System.Text.Encoding]::UTF8)
    
    $writer.Write('<!DOCTYPE html>')
    $writer.Write([char]10)
    $writer.Write('<html lang="en-us">')
    $writer.Write([char]10)
    $writer.Write('<head>')
    $writer.Write([char]10)
    $writer.Write('<meta charset="utf-8">')
    $writer.Write([char]10)
    $writer.Write('<meta http-equiv="Content-Type" content="text/html; charset=utf-8">')
    $writer.Write([char]10)
    $writer.Write('<title>Masked Special Forces</title>')
    $writer.Write([char]10)
    $writer.Write('<style>')
    $writer.Write([char]10)
    $writer.Write($css)
    $writer.Write([char]10)
    $writer.Write('</style>')
    $writer.Write([char]10)
    $writer.Write('<style>body { overflow: hidden; }</style>')
    $writer.Write([char]10)
    $writer.Write('<script>')
    $writer.Write([char]10)
    $writer.Write($unityProgress)
    $writer.Write([char]10)
    $writer.Write('</script>')
    $writer.Write([char]10)
    $writer.Write('<script>')
    $writer.Write([char]10)
    $writer.Write($unityLoader)
    $writer.Write([char]10)
    $writer.Write('</script>')
    $writer.Write([char]10)
    $writer.Write('<script>')
    $writer.Write([char]10)
    
    $writer.Write($bootPre)
    $writer.Write($gameDataB64)
    $writer.Write($bootMid1)
    $writer.Write([char]10)
    $writer.Write($bootMid2)
    $writer.Write($wasmCodeB64)
    $writer.Write($bootMid1)
    $writer.Write([char]10)
    $writer.Write($bootMid3)
    $writer.Write($wasmFrameworkB64)
    $writer.Write($bootMid1)
    $writer.Write([char]10)
    $writer.Write($bootPost)
    
    $writer.Write([char]10)
    $writer.Write('</script>')
    $writer.Write([char]10)
    $writer.Write('</head>')
    $writer.Write([char]10)
    $writer.Write('<body onfocus="FitScreen();" onload="FitScreen();" onresize="FitScreen();" style="width:100%; height:100%; margin:0; background:#231F20">')
    $writer.Write([char]10)
    $writer.Write('<div class="webgl-content">')
    $writer.Write([char]10)
    $writer.Write('<div id="gameContainer" style="width: auto; height: auto"></div>')
    $writer.Write([char]10)
    $writer.Write('</div>')
    $writer.Write([char]10)
    $writer.Write('</body>')
    $writer.Write([char]10)
    $writer.Write('</html>')
    
    $writer.Close()
    
    $len = (Get-Item "D:\khent\Masked_Special_Forces.html").Length
    Write-Output "HTML file size: $len bytes ($([math]::Round($len/1MB, 2)) MB)"
}

Build-Html
