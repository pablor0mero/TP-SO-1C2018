$salir = 0;
$cantidad_lectores = 0;
$cantidad_escritores  = 0;

@colaDeEjecucion = ();


use strict;
use warnings;
use threads;

# Comandos disponibles aca
print "Comandos disponibles:\n"
print " - crear-lector [tiempo-llegada] [tiempo-lectura]\n"
print " - crear-escritor [tiempo-llegada] [tiempo-escritura]\n"
print " - listar <[escritores lectores todos]>\n"
print " - salir\n"

while($salir == 0) {
    chomp(my $input = <STDIN>);
    
    my @splittedInput = split / /, $input;
    my $parametersCount = scalar @splittedInput;

    my $command = @splittedInput[0];
    
    switch($command) {
        case "crear-lector" {
            # crear hilo de lector
            $cantidad_lectores += 1;
            my %threadHash = ($cantidad_lectores, threads->create(hiloLector))

            push @colaDeEjecucion, %threadHash
        }

        case "crear-escritor" {
            # crear hilo de escritor
        }

        case "listar" {
            #listar colas
            print @colaDeEjecucion
        }

        case "salir" {
            $salir = 1;
        }

        else {
            print "Comando invalido\n"
        }

    }

}

sub hiloLector {

}

sub hiloEscritor {

}