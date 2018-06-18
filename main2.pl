#!/usr/bin/perl 
### Variables Globales ###

#Variables de menu y contadores
my $salir = 0;
my $idHilo = 0;
# Variable compartida para exclusion mutua

my $escribiendoEnBd : shared = 0;
my $leyendoEnBd : shared = 0;

my @colaDeEjecucion = ();

use strict;
use warnings;
use threads;
use Switch;
use threads::shared;
use Thread::Semaphore;
my $sPlani = Thread::Semaphore->new();
my $id :shared = 0;

my $planificador = {
            hiloListo => [
                     #{
                     #  id => $idHilo,
                     #  tipo => 'L',
                     #}
                   ],
            hiloEjecutando
            => [
                ],
            hiloFinalizado
            => [
                ],
             };

my $hilo = {};


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
        
    switch($command) {
        case "crear-lector" {
            # crear hilo de lector
            
            #until(threads->list(threads::running)<4){
            #    print "Hay 4 threads corriendo no se pueden crear más hasta que no se libere 1\n";
            #    sleep 1;
            #    }
                        
            
            $idHilo +=1;
            $hilo = {id => $idHilo ,tipo => 'L'};
            push @{$planificador->{hiloListo}}, $hilo;                      
                          
            my $t = threads->create('hiloLector', $idHilo, $splittedInput[1]);
            #push @colaDeEjecucion, $hilo; 
            
        }
    
    
        case "crear-escritor" {
            # crear hilo de escritor

            $idHilo +=1;

            $hilo = {id => $idHilo ,tipo => 'E'};
            push @{$planificador->{hiloListo}}, $hilo;
            
            my $t = threads->create('hiloEscritor', $idHilo, $splittedInput[1]);
            

            
        }
    
        case "listar" {
            #listar colas
            #while(my $threads=threads->list(threads::running)){
            #    print "Threads ejecutandose: $threads \n";
            #    sleep 1;
            #    }
            #print @colaDeEjecucion
            
        }
    
        case "salir" {
            $salir = 1;
        }
        
        else {
            print 'Comando invalido\n'
        }
    }
}


sub hiloLector {
      
      my ($id,$sleep) = @_;
      my $self = threads->self(); # referencia al objeto thread
      my $tid = $self->tid();
      my $out = $tid;
            
      while ($escribiendoEnBd != 0)
      {
        print "Soy el Hilo Lector Id: ".$id . " , estoy esperando\n";
        sleep(1);
        
      }
      #Exclusion para el uso de la cola de Listos
      print " Mi id es: ",$id, " espero semaforo\n";
      $sPlani->down();
                    
      $leyendoEnBd +=1;
      
      print "Soy el Hilo Lector Id: ".$id . " , estoy ejecutando: ".$sleep . "seg\n" ;
      sleep($sleep);
      
      #push @{$planificador->{hiloEjecutando}}, shift @{$planificador->{hiloListo}};
      shift @{$planificador->{hiloListo}};
      
      
      print "Nuevo primero: " , $planificador->{hiloListo}->[0]->{id} , "\n",
      $sPlani->up();
      
      $leyendoEnBd -=1;
      
      print "--Lector-id:",$id," Finalizado\n";
      
}

sub hiloEscritor {
        my ($id,$sleep) = @_;
        my $self = threads->self(); # referencia al objeto thread
        my $tid = $self->tid();
        my $out = $tid;
      
               
        # Espero hasta que no haya nadie leyendo
        while ($leyendoEnBd != 0)
        
        {
            # print "Soy el Hilo Escritor Id: ".$id . " , estoy esperando lectura\n";
            #sleep(1);
            #
        }
        
        # Espero hasta que no haya nadie escribiendo
        while ($escribiendoEnBd != 0)
        {
              #print "Soy el Hilo Escritor Id: ".$id . " , estoy esperando escritura\n";
              #sleep(1);
        
        }
        # Activo mutex de escritura
        $escribiendoEnBd =1;
      
        print "Soy el Hilo Escritor Id: ".$id . " , estoy esribiendo por: ".$sleep . "seg\n";
        sleep($sleep);
      
        # Desactivo mutex de escritura
        $escribiendoEnBd =0;
        
        print "Escritor-id:",$id," Finalizado\n";   
        return $out;
   
}
