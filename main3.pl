#!/usr/bin/perl 
#use strict;
use warnings;
use threads;
#use Switch;
use threads::shared;
use Thread::Semaphore;
use Data::Dumper;

### Variables Globales ###

#Variables de menu y contadores
my $salir = 0;
my $idHilo : shared= 0;

# Semaforos y contadores
my $inSem = Thread::Semaphore->new();
my $outSem = Thread::Semaphore->new();
my $wrtSem = Thread::Semaphore->new(0);
my $ctrin : shared = 0;
my $ctrout : shared = 0;
my $wait : shared = 0;


# Comandos disponibles aca
print "Comandos disponibles:\n";
print " - crear-lector [tiempo-lectura]\n";
print " - crear-escritor [tiempo-escritura]\n";
print " - listar <[escritores lectores todos]>\n";
print " - salir\n"  ;


while($salir == 0) {
  chomp(my $input = <STDIN>);
    
    my @splittedInput = split / /, $input;
    my $parametersCount = scalar @splittedInput;

    my $command = $splittedInput[0];
        
    if( $command eq "crear-lector") {
        # crear hilo de lector
        
        #until(threads->list(threads::running)<4){
        #    print "Hay 4 threads corriendo no se pueden crear más hasta que no se libere 1\n";
        #    sleep 1;
        #    }
                    
        
        $idHilo +=1;                 
                        
        my $t = threads->create('hiloLector', $idHilo, $splittedInput[1]);
        
    }
    elsif($command eq "crear-escritor") {
        # crear hilo de escritor

        $idHilo +=1;
        
        my $t = threads->create('hiloEscritor', $idHilo, $splittedInput[1]);
    }
    elsif( $command eq "listar") {

    }
    elsif( $command eq "salir") {
        $salir = 1;
    }
    else {
        print 'Comando invalido\n';
    }
    
}


sub hiloLector {
      
    my ($id,$sleep) = @_;
    my $self = threads->self(); 
    my $tid = $self->tid();
    my $out = $tid;

    $inSem->down();
    $ctrin += 1;
    $inSem->up();

    print "Soy el Hilo Lector Id: ".$id . " , estoy ejecutando: ".$sleep . "seg\n" ;
    sleep($sleep);

    $outSem->down();
    $ctrout += 1;

    if($wait == 1 && $ctrin == $ctrout) {
        $wrtSem->up();
    }

    $outSem->up();
   
    print "--Lector-id:",$id," Finalizado\n";
      
    return $out
}

sub hiloEscritor {
        my ($id,$sleep) = @_;
        my $self = threads->self(); # referencia al objeto thread
        my $tid = $self->tid();
        my $out = $tid;


        $inSem->down();
        $outSem->down();

        if($ctrin == $ctrout) {
            $outSem->up();
        }
        else {
            $wait = 1;
            $outSem->up();
            $wrtSem->down();
            $wait = 0;
        }

        print "Soy el Hilo Escritor Id: ".$id . " , estoy esribiendo por: ".$sleep . "seg\n";
        sleep($sleep);

        $inSem->up();
        
        print "Escritor-id:",$id," Finalizado\n";  

        return $out;
   
}
